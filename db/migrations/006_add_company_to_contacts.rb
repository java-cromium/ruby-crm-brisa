# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:contacts) do
      add_column :company, String
    end
  end
end
