# frozen_string_literal: true
require "mongoid/full_text_search/services/calculate_ngrams"

module Mongoid
  module FullTextSearch
    module Mappings
      extend ActiveSupport::Concern

      class_methods do
        def fulltext_search_in(*args)
          options = args.last.is_a?(Hash) ? args.pop : {}

          index_name = options.fetch(:index_name) do
            "mongoid_fulltext.index_#{name.downcase}_#{mongoid_fulltext_config.count}"
          end

          config = DEFAULT_CONFIG.dup.update(options)

          args = [:to_s] if args.empty?
          config[:ngram_fields] = args
          config[:alphabet] = Hash[config[:alphabet].split('').map { |ch| [ch, ch] }]
          config[:word_separators] = Hash[config[:word_separators].split('').map { |ch| [ch, ch] }]

          mongoid_fulltext_config[index_name] = config

          before_save(:update_ngram_index) if config[:reindex_immediately]
          before_destroy(:remove_from_ngram_index)
        end

        def update_ngram_index
          all.each(&:update_ngram_index)
        end

        def remove_from_ngram_index
          mongoid_fulltext_config.each_pair do |index_name, _|
            ::I18n.available_locales.each do |locale|
              localized_index_collection = index_collection_for_name_and_locale(index_name, locale)
              localized_index_collection.remove_ngrams(self)
            end
          end
        end

        def index_collection_for_name_and_locale(index_name, locale)
          # collection_name = localized_index_name(index_name, locale)
          # IndexCollection.new(collection.database[collection_name.to_sym])
          IndexCollection.for(self, name: index_name, locale: locale)
        end
      end

      def update_ngram_index
        mongoid_fulltext_config.each_pair do |index_name, fulltext_config|
          ::I18n.available_locales.each do |locale|
            if condition = fulltext_config[:update_if]
              case condition
              when Symbol then  next unless send(condition)
              when String then  next unless instance_eval(condition)
              when Proc   then  next unless condition.call(self)
              else; next
              end
            end

            localized_index_collection = self.class.index_collection_for_name_and_locale(index_name, locale)
            localized_index_collection.remove_ngrams(self)

            ngrams = extract_ngrams_from_fields(fulltext_config, locale)

            return if ngrams.empty?

            filter_values = apply_filters(fulltext_config)

            localized_index_collection.insert_ngrams(self, ngrams, filter_values)
          end
        end
      end

      def remove_from_ngram_index
        mongoid_fulltext_config.each_pair do |index_name, _|
          ::I18n.available_locales.each do |locale|
            localized_index_collection = self.class.index_collection_for_name_and_locale(index_name, locale)
            localized_index_collection.remove_ngrams(self)
          end
        end
      end

      private

      def apply_filters(fulltext_config)
        return unless fulltext_config.key?(:filters)
        Hash[
          fulltext_config[:filters].map do |key, value|
            begin
              [key, value.call(self)]
            rescue StandardError # Suppress any exceptions caused by filters
            end
          end.compact
        ]
      end

      def extract_ngrams_from_fields(fulltext_config, locale)
        ngram_fields = fulltext_config[:ngram_fields]

        field_values = ngram_fields.map do |field_name|
          next send(field_name) if field_name == :to_s
          next unless field = self.class.fields[field_name.to_s]
          if field.localized?
            send("#{field_name}_translations")[locale]
          else
            send(field_name)
          end
        end

        field_values.map do |field_value|
          Services::CalculateNgrams.call(field_value, fulltext_config, false)
        end.flatten
      end
    end
  end
end
