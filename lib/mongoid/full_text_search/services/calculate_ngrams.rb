require "unicode_utils"
require "mongoid/full_text_search/ngram"

module Mongoid
  module FullTextSearch
    module Services
      class CalculateNgrams < Struct.new(:str, :config, :bound_number_returned)
        def self.call(*args)
          new(*args).call
        end

        def initialize(str, config, bound_number_returned = true)
          if str && config[:remove_accents]
            if defined?(UnicodeUtils)
              str = UnicodeUtils.nfkd(str)
            elsif defined?(DiacriticsFu)
              str = DiacriticsFu.escape(super)
            end
          end

          super(str, config, bound_number_returned)
        end

        def call
          return {} unless str

          # Create an array of records of the form {:ngram => x, :score => y} for all ngrams that occur in the
          # input string using the step size that we just computed. Let score(x,y) be the score of string x
          # compared with string y - assigning scores to ngrams with the square root-based scoring function
          # below and multiplying scores of matching ngrams together yields a score function that has the
          # property that score(x,y) > score(x,z) for any string z containing y and score(x,y) > score(x,z)
          # for any string z contained in y.
          ngrams = build_ngram_array

          # If an ngram appears multiple times in the query string, keep the max score
          ngrams = ngrams.group_by(&:name).map do |name, ngrams|
            Ngram.new(name: name, score: ngrams.map(&:score).max)
          end

          # Add 'short prefix' records to the array: prefixes of the string that are length (ngram_width - 1)
          ngrams += short_prefixes if index_short_prefixes?

          # Add records to the array of ngrams for each full word in the string that isn't a stop word
          ngrams += full_words if index_full_words?

          # If an ngram appears as any combination of full word, short prefix, and ngram, keep the sum of the two scores
          ngrams.group_by(&:name).map do |name, ngrams|
            Ngram.new(name: name, score: ngrams.map(&:score).sum)
          end
        end

        private

        def build_ngram_array
          (0..filtered_str.length - ngram_width).step(step_size).map do |i|
            score = if i == 0 || (apply_prefix_scoring_to_all_words? && word_separators.key?(filtered_str[i - 1].chr))
                      Math.sqrt(1 + 1.0 / filtered_str.length)
                    else
                      Math.sqrt(2.0 / filtered_str.length)
                    end

            Ngram.new(name: filtered_str[i..i + ngram_width - 1], score: score)
          end
        end

        def short_prefixes
          prefixes_seen = {}
          all_words.each_with_object([]) do |word, res|
            next res if word.length < ngram_width - 1
            prefix = word[0...ngram_width - 1]
            if prefixes_seen[prefix].nil? && (stop_word?(word) || filtered_str?(word))
              res << Ngram.new(name: prefix, score: 1 + 1.0 / filtered_str.length )
              prefixes_seen[prefix] = true
            end
          end
        end

        def full_words
          full_words_seen = {}
          all_words.each_with_object([]) do |word, res|
            if word.length > 1 && full_words_seen[word].nil? && (stop_word?(word) || filtered_str?(word))
              res << Ngram.new(name: word, score: 1 + 1.0 / filtered_str.length )
              full_words_seen[word] = true
            end
          end
        end

        def filtered_str?(word)
          word == filtered_str
        end

        def stop_word?(word)
          stop_words[word].nil?
        end

        def index_short_prefixes?
          config[:index_short_prefixes]
        end

        def index_full_words?
          config[:index_full_words]
        end

        def alphabet
          config[:alphabet]
        end

        def word_separators
          config[:word_separators]
        end

        def ngram_width
          config[:ngram_width]
        end

        def max_ngrams_to_search
          config[:max_ngrams_to_search]
        end

        def remove_accents?
          config[:remove_accents]
        end

        def apply_prefix_scoring_to_all_words?
          config[:apply_prefix_scoring_to_all_words]
        end

        def stop_words
          config[:stop_words]
        end

        def all_words
          filtered_str.split(split_regex)
        end

        # Remove any characters that aren't in the alphabet and aren't word separators
        def filtered_str
          str
            .mb_chars
            .downcase
            .to_s.split("")
            .find_all { |ch| alphabet[ch] || word_separators[ch] }
            .join("")
        end

        # Figure out how many ngrams to extract from the string. If we can't afford to extract all ngrams,
        # step over the string in evenly spaced strides to extract ngrams. For example, to extract 3 3-letter
        # ngrams from 'abcdefghijk', we'd want to extract 'abc', 'efg', and 'ijk'.
        def step_size
          return 1 unless bound_number_returned
          [((filtered_str.length - ngram_width).to_f / max_ngrams_to_search).ceil, 1].max
        end

        def split_regex_def
          word_separators.keys.map { |k| Regexp.escape(k) }.join
        end

        def split_regex
          Regexp.compile("[#{split_regex_def}]")
        end
      end
    end
  end
end
