# frozen_string_literal: true
module Mongoid
  module FullTextSearch
    class NgramCursor
      attr_reader :ngram_score, :count, :query

      delegate :score, to: :ngram_score

      def initialize(ngram_score:, count:, query:)
        @ngram_score = ngram_score
        @count = count
        @query = query
      end

      def empty?
        count == 0
      end

      def <=>(other)
        count <=> other.count
      end
    end
  end
end
