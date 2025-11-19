class Report < ApplicationRecord
  # Associations
  belongs_to :user
  # Validations
  enum :report_type, { fte: "fte", erlang: "erlang" }
  validates :report_type, presence: true
  # Imports
  require "csv"

  def to_csv
    return "" if results.blank?

    CSV.generate(headers: true) do |csv|
      csv << results["columns"]

      Array(results["rows"]).each do |row|
        csv << row
      end
    end
  end
end
