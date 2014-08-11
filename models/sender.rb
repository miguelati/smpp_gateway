class Sender
  include Mongoid::Document
  include Mongoid::Timestamps
  embeds_one :dlr

  field :from, type: String
  field :to, type: String
  field :message, type: String
  field :status, type: String
  field :app, type: String
  field :id_message, type: String
  field :dlr_type, type: String
  field :dlr_error, type: String

end