class Sender
  include Mongoid::Document
  include Mongoid::Timestamps

  field :from, type: String
  field :to, type: String
  field :message, type: String
  field :status, type: String
  field :app, type: String

end