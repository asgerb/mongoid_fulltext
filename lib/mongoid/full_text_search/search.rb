module Mongoid
  module FullTextSearch
    class Search

      def initialize(collection:, config:)
        @collection = collection
        @config = config
        @query = ""
      end

      def self.on(collection:, config:)
        new(collection: collection, config: config)
      end

      def for(query)
        self.query = query
        self
      end

      def results(max:, filters:)
        # For each ngram, construct the query we'll use to pull index documents and
        # get a count of the number of index documents containing that n-gram
        cursors = collection.ngram_cursors(ngrams, filters)

        # Using the queries we just constructed and the n-gram frequency counts we
        # just computed, pull in about *:max_candidate_set_size* candidates by
        # considering the n-grams in order of increasing frequency. When we've
        # spent all *:max_candidate_set_size* candidates, pull the top-scoring
        # *max_results* candidates for each remaining n-gram.
        candidates = collection.candidates(cursors, max)

        # Finally, score all candidates by matching them up with other candidates that are
        # associated with the same document. This is similar to how you might process a
        # boolean AND query, except that with an AND query, you'd stop after considering
        # the first candidate list and matching its candidates up with candidates from other
        # lists, whereas here we want the search to be a little fuzzier so we'll run through
        # all candidate lists, removing candidates as we match them up.
        results = candidates
          .group_by(&:document_id)
          .map do |document_id, candidates|
            Result.new(
              document_id: document_id,
              class_name: candidates.first.class_name,
              score: candidates.sum(&:score)
            )
          end
          .sort[0...max]
      end

      private

      attr_reader :collection
      attr_reader :config
      attr_accessor :query

      def ngrams
        Services::CalculateNgrams.call(query, config)
      end
    end
  end
end
