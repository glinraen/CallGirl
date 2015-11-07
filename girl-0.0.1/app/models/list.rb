class List
  include Mongoid::Document
  field :name, type: String
  field :desc, type: String
  field :classification, type: String
  field :segment, type: String
  field :slice, type: Integer
  field :share, type: Float
  field :zone, type: Time
  field :department, type: String
end
