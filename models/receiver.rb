class Receiver
  include Mongoid::Document
  include Mongoid::Timestamps

  field :from, type: String
  field :to, type: String
  field :message, type: String
  field :app, type: String
  field :incoming_at, type: DateTime
  field :delivery_report_value, type: String
  field :metadata_tlv, type: String
  

end