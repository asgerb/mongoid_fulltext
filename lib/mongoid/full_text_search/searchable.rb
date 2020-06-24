# frozen_string_literal: true
require "mongoid/full_text_search/services/calculate_ngrams"
require "mongoid/full_text_search/index_collection"
require "mongoid/full_text_search/search"

module Mongoid
  module FullTextSearch
    module Searchable
      extend ActiveSupport::Concern

      DEFAULT_MAX_RESULTS = 10
      DEFAULT_RETURN_SCORES = false

      class_methods do
        def fulltext_search(query_string, options = {})
          max_results = options.fetch(:max_results, DEFAULT_MAX_RESULTS)
          return_scores = options.fetch(:return_scores, DEFAULT_RETURN_SCORES)

          if mongoid_fulltext_config.count > 1 && !options.key?(:index)
            error_message = '%s is indexed by multiple full-text indexes. You must specify one by passing an :index parameter'
            raise UnspecifiedIndexError, error_message % name, caller
          end

          index_name = options.fetch(:index, mongoid_fulltext_config.keys.first)
          config = mongoid_fulltext_config[index_name]
          index_collection = IndexCollection.for(self, name: index_name, locale: ::I18n.locale)
          filters = query_filters(filter_options).merge(document_type_filters)
          results = Search
            .on(collection: index_collection, config: config)
            .for(query_string)
            .results(max: max_results, filters: filters)

          instantiate_mapreduce_results(results: results, include_scores: return_scores)
        end

        private

        def instantiate_mapreduce_results(results:, include_scores:)
          if include_scores
            results
              .map { |result| [result.query(criteria: criteria), result.score] }
              .reject { |result_and_score| result_and_score.first.blank? }
          else
            results
              .map { |result| result.query(criteria: criteria) }
              .compact
          end
        end

        def query_filters(options)
          Hash[
            options.map do |key, value|
              case value
              when Hash then
                if    value.key? :any then format_filter("$in", key, value[:any])
                elsif value.key? :all then format_filter("$all", key, value[:all])
                else  raise UnknownFilterQueryOperator, value.keys.join(","), caller
                end
              else format_filter("$all", key, value)
              end
            end
          ]
        end

        # add filter by type according to SCI classes
        def document_type_filters
          return {} if fields["_type"].blank?
          kls = ([self] + descendants).map(&:to_s)
          { class: { "$in" => kls } }
        end
      end
    end
  end
end
