require 'sequel'

Sequel.migration do
  up do
    alter_table(:tasks) do
      add_foreign_key :contact_id, :contacts, null: true
      add_foreign_key :customer_id, :customers, null: true
    end
  end

  down do
    alter_table(:tasks) do
      drop_column :contact_id
      drop_column :customer_id
    end
  end
end
