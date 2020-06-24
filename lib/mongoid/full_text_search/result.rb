# frozen_string_literal: true
module Mongoid
  module FullTextSearch
    class Result
      attr_reader :document_id
      attr_reader :class_name
      attr_reader :score

      def initialize(document_id:, class_name:, score:)
        @document_id = document_id
        @class_name = class_name
        @score = score
      end

      def query(criteria:)
        if criteria.selector.empty?
          class_name.constantize.find(document_id)
        else
          criteria.where(_id: document_id).first
        end
      end

      def <=>(other)
        -score <=> -other.score
      end
    end
  end
end
