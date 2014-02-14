class Dlr
  include Mongoid::Document
  include Mongoid::Timestamps

  field :type, type: String
  field :error, type: String
  field :message_id, type: String
  field :app, type: String

end