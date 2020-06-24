# frozen_string_literal: true
module Mongoid
  module FullTextSearch
    class NgramScore
      attr_reader :ngram, :score

      def initialize(ngram:, score:)
        @ngram = ngram
        @score = score
      end

      def to_h
        { ngram => score }
      end
    end
  end
end
