# encoding : utf-8

Sequel.migration do
  up do
    create_table(:Stats) do
      primary_key :id
      foreign_key :link_id, :Stats, key: :id
      String :likes_count
      String :shares_count
      DateTime :download_time
    end
  end

  down do
    drop_table(:Stats)
  end
end