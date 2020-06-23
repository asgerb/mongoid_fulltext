module Mongoid
  module FullTextSearch
    class NgramCursor
      attr_reader :ngram, :count, :query

      delegate :score, to: :ngram

      def initialize(ngram:, count:, query:)
        @ngram = ngram
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
