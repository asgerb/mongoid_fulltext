# frozen_string_literal: true
module Mongoid
  module FullTextSearch
    class Ngram
      attr_reader :name, :score

      def initialize(name:, score:)
        @name = name
        @score = score
      end

      def ngram
        name
      end

      def to_h
        { ngram => score }
      end
    end
  end
end
