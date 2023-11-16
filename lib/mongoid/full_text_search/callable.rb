# frozen_string_literal: true
module Mongoid
  module FullTextSearch
    module Callable
      extend ActiveSupport::Concern

      included do
        private_class_method :new
      end

      class_methods do
        def call(*args, **kwargs)
          new(*args, **kwargs).call
        end
      end

      def call
        raise NotImplementedError
      end
    end
  end
end
