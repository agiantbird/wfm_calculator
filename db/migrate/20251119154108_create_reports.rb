class CreateReports < ActiveRecord::Migration[7.2]
  def change
    create_table :reports do |t|
      t.references :user, null: false, foreign_key: true
      t.string :report_type, null: false
      t.string :name
      t.jsonb :parameters, default: {}
      t.jsonb :results, default: {}

      t.timestamps
    end

    add_index :reports, :report_type
  end
end
