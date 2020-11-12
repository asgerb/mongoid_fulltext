class NoFieldArtist
  include Mongoid::Document
  include Mongoid::FullTextSearch

  field :first_name
  field :last_name

  def name
    [first_name, last_name].join(' ')
  end

  fulltext_search_in :name
end