require 'mongoid/full_text_search/services/index_definition'

module Mongoid
  module FullTextSearch
    module Indexes
      extend ActiveSupport::Concern

      delegate :localize_fulltext_index?, to: :class

      class_methods do
        def create_fulltext_indexes
          return unless mongoid_fulltext_config

          mongoid_fulltext_config.each_pair do |index_name, config|
            ::I18n.available_locales.each do |locale|
              fulltext_search_ensure_indexes(index_name, locale, config)
            end
          end
        end

        def localized_index_name(name, locale)
          return name unless localize_fulltext_index?
          "#{name}_#{locale}"
        end

        def fulltext_search_ensure_indexes(index_name, locale, config)
          index_collection = IndexCollection.for(self, name: index_name, locale: locale)
          filters = config.fetch(:filters, [])
          index_definition = Services::IndexDefinition.call(index_collection, filters)

          if Mongoid.logger
            Mongoid.logger.info("Ensuring fts_index on #{index_collection.name}: #{index_definition}")
          end
          index_collection.create_index(Hash[index_definition], name: "fts_index")

          if Mongoid.logger
            Mongoid.logger.info("Ensuring document_id index on #{index_collection.name}")
          end
          index_collection.create_index({ document_id: 1 })
        end

        def localize_fulltext_index?
          fields.values.any?(&:localized?) && ::I18n.available_locales.count > 1
        end
      end
    end
  end
end
