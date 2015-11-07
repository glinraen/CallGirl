json.array!(@lists) do |list|
  json.extract! list, :id, :name, :desc, :classification, :segment, :slice, :share, :zone, :department
  json.url list_url(list, format: :json)
end
