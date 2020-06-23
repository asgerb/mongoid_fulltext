module Mongoid
  module FullTextSearch
    class Candidate
      def initialize(candidate_result, ngram_cursor)
        @candidate_result = candidate_result
        @ngram_cursor = ngram_cursor
      end

      def document_id
        candidate_result[:document_id]
      end

      def class_name
        candidate_result[:class]
      end

      def score
        candidate_result[:score] * ngram_cursor.score
      end

      private

      attr_reader :candidate_result
      attr_reader :ngram_cursor
    end
  end
end
