# frozen_string_literal: true
require_relative "callable"

module Mongoid
  module FullTextSearch
    class IndexDefinition
      include Callable

      def initialize(collection, filters)
        @collection = collection
        @filters = filters
        # The order of filters matters when the same index is used from two or more collections.
        @filter_indexes = @filters.map { |key, _| ["filter_values.#{key}", 1] }.sort_by(&:first)
        @filter_keys = @filter_indexes.map(&:first)
      end

      def call
        res = index_definition

        # Since the definition of the index could have changed, we'll clean up
        # by removing any indexes that aren't on the exact.
        clean_up_indexes

        if @filter_keys.length > @filter_indexes.length
          updated_filter_indexes = @filter_keys.map { |key| [key, 1] }.sort_by(&:first)
          res = index_definition(filter: updated_filter_indexes)
        end

        res
      end

      private

      def clean_up_indexes
        @collection.indexes.each do |idef|
          keys = idef["key"].keys
          next unless keys.member?("ngram")
          @filter_keys |= keys.find_all { |key| key.starts_with?("filter_values.") }
          next unless keys & correct_keys != correct_keys
          Mongoid.logger.info "Dropping #{idef['name']} [#{keys & correct_keys} <=> #{correct_keys}]" if Mongoid.logger
          @collection.indexes.send DROP_INDEX_METHOD_NAME, idef['key']
        end
      end

      def index_definition(filter: @filter_indexes)
        [["ngram", 1], ["score", -1]].concat(filter)
      end

      def correct_keys
        index_definition.map { |field_def| field_def[0] }
      end
    end
  end
end
