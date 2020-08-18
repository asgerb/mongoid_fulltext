# frozen_string_literal: true
require "mongoid/full_text_search/ngram_cursor"
require "mongoid/full_text_search/candidate"

module Mongoid
  module FullTextSearch
    class IndexCollection
      SCORE_ORDER = { "score" => 1 }
      CREATE_INDEX_METHOD_NAME = Compatibility::Version.mongoid5_or_newer? ? :create_one : :create
      DELETE_FROM_INDEX_METHOD_NAME = Compatibility::Version.mongoid5_or_newer? ? :delete_many : :remove_all
      DROP_INDEX_METHOD_NAME = Compatibility::Version.mongoid5_or_newer? ? :drop_one : :drop
      INSERT_METHOD_NAME = Compatibility::Version.mongoid5_or_newer? ? :insert_one : :insert
      DEFAULT_MAX_RESULTS = 10

      delegate(:find, :name, :indexes, to: :collection)

      class << self
        def for(document_or_class, name:, locale: ::I18n.locale, max_candidate_set_size: 1000)
          name = "#{name}_#{locale}" if document_or_class.localize_fulltext_index?
          new(
            collection: document_or_class.collection.database[name],
            max_candidate_set_size: max_candidate_set_size
          )
        end
      end

      def initialize(collection:, max_candidate_set_size:)
        @collection = collection
        @max_candidate_set_size = max_candidate_set_size
      end

      # For each ngram, construct the query we'll use to pull index documents and
      # get a count of the number of index documents containing that n-gram
      def ngram_cursors(ngram_scores, filters)
        return [] if ngram_scores.blank?
        ngram_scores.map do |ngram_score|
          query = { "ngram" => ngram_score.ngram }
          query.update(filters)
          count = find(query).count
          NgramCursor.new(ngram_score: ngram_score, count: count, query: query)
        end
      end

      # => [Candidate, Candidate, Candidate]
      def candidates(ngram_cursors, limit)
        results_so_far = 0
        ngram_cursors.reject(&:empty?).sort.map do |ngram_cursor|
          query_result = find(ngram_cursor.query)
          # TODO: neither of the below if statement paths are excercised in the spec
          if results_so_far >= max_candidate_set_size
            query_result = query_result.sort(SCORE_ORDER).limit(limit)
          elsif ngram_cursor.count > max_candidate_set_size - results_so_far
            query_result = query_result.sort(SCORE_ORDER).limit(max_candidate_set_size - results_so_far)
          end
          results_so_far += ngram_cursor.count
          query_result.map do |candidate_result|
            Candidate.new(candidate_result, ngram_cursor)
          end
        end.compact.flatten
      end

      def results(candidates:, max: DEFAULT_MAX_RESULTS)
        return [] if candidates.empty?
        candidates
          .group_by(&:document_id)
          .map do |document_id, candidates|
            Result.new(
              document_id: document_id,
              class_name: candidates.first.class_name,
              score: candidates.sum(&:score)
            )
          end
          .sort[0...max]
      end

      def create_index(index, options={})
        indexes.send(CREATE_INDEX_METHOD_NAME, index, options)
      end

      def insert_ngrams(document, ngram_scores, filter_values)
        ngram_scores.each do |ngram_score|
          insert_ngram(document, ngram_score, filter_values)
        end
      end

      def insert_ngram(document, ngram_score, filter_values)
        index_document = {
          class: document.class.name,
          document_id: document._id,
          ngram: ngram_score.ngram,
          score: ngram_score.score
        }

        if filter_values.present?
          index_document[:filter_values] = filter_values
        end

        collection.send(INSERT_METHOD_NAME, index_document)
      end

      def remove_ngrams(document_or_class)
        query = case document_or_class
                when Class then find(class: document_or_class.name)
                           else find(document_id: document_or_class._id)
                end
        query.send(DELETE_FROM_INDEX_METHOD_NAME)
      end

      private

      attr_reader :collection
      attr_reader :max_candidate_set_size
    end
  end
end
