# encoding : utf-8

Sequel.migration do
  up do
    create_table(:Links) do
      primary_key :id
      String :url
      String :domain
      String :facebook_id
      String :facebook_likes
    end
  end

  down do
    drop_table(:Links)
  end
end