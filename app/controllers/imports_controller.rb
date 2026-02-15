require "csv"

class ImportsController < ApplicationController

  US_STATES = {
    "AL" => "Alabama", "AK" => "Alaska", "AZ" => "Arizona",
    "AR" => "Arkansas", "CA" => "California", "CO" => "Colorado",
    "CT" => "Connecticut", "DE" => "Delaware", "FL" => "Florida",
    "GA" => "Georgia", "HI" => "Hawaii", "ID" => "Idaho",
    "IL" => "Illinois", "IN" => "Indiana", "IA" => "Iowa",
    "KS" => "Kansas", "KY" => "Kentucky", "LA" => "Louisiana",
    "ME" => "Maine", "MD" => "Maryland", "MA" => "Massachusetts",
    "MI" => "Michigan", "MN" => "Minnesota", "MS" => "Mississippi",
    "MO" => "Missouri", "MT" => "Montana", "NE" => "Nebraska",
    "NV" => "Nevada", "NH" => "New Hampshire", "NJ" => "New Jersey",
    "NM" => "New Mexico", "NY" => "New York", "NC" => "North Carolina",
    "ND" => "North Dakota", "OH" => "Ohio", "OK" => "Oklahoma",
    "OR" => "Oregon", "PA" => "Pennsylvania", "RI" => "Rhode Island",
    "SC" => "South Carolina", "SD" => "South Dakota", "TN" => "Tennessee",
    "TX" => "Texas", "UT" => "Utah", "VT" => "Vermont",
    "VA" => "Virginia", "WA" => "Washington", "WV" => "West Virginia",
    "WI" => "Wisconsin", "WY" => "Wyoming"
  }

  def new
  end

  # ========================
  # PREVIEW CSV
  # ========================
  def preview
    file = params[:file]
    return redirect_to root_path, alert: "No file uploaded" unless file

    @rows = []
    @errors = []

    csv_options = { headers: true, header_converters: :symbol }
    seen_rows = {}

    CSV.foreach(file.path, **csv_options).with_index(2) do |row, line_number|
      building_name  = row[:building_name].to_s.strip
      street_address = row[:street_address].to_s.strip
      unit           = row[:unit].to_s.strip
      city           = row[:city].to_s.strip
      state_input    = row[:state].to_s.strip
      zip_code       = row[:zip_code].to_s.strip

      state = normalize_state(state_input)

      address_display = build_address_display(
        street_address, city, (state || state_input), zip_code, unit
      )

      # Required fields (Unit NOT required)
      missing_fields = []
      missing_fields << "Building Name" if building_name.blank?
      missing_fields << "Street Address" if street_address.blank?
      missing_fields << "City" if city.blank?
      missing_fields << "State" if state.blank?
      missing_fields << "Zip Code" if zip_code.blank?

      if missing_fields.any?
        @errors << %(Line #{line_number}: "#{address_display}" Missing required fields (#{missing_fields.join(", ")}))
        next
      end

      unless zip_code.match?(/\A\d{5,}\z/)
        @errors << %(Line #{line_number}: "#{address_display}" Invalid Zip Code (must be at least 5 digits and numbers only))
        next
      end

      normalized_unit = unit.present? ? unit.downcase : "__NO_UNIT__"

      dedupe_key = [
        building_name.downcase,
        street_address.downcase,
        normalized_unit,
        city.downcase,
        state.downcase,
        zip_code
      ].join("|")

      if seen_rows.key?(dedupe_key)
        @errors << %(Line #{line_number}: "#{address_display}" Duplicate entry (matches line #{seen_rows[dedupe_key]}))
        next
      end
      seen_rows[dedupe_key] = line_number

      @rows << {
        building_name: building_name,
        street_address: street_address,
        unit: unit.presence,
        city: city,
        state: state,
        zip_code: zip_code,
        full_address: build_address_display(street_address, city, state, zip_code, unit)
      }
    end

    # Store preview rows in database (NOT session)
    batch = ImportBatch.create!(payload: { rows: @rows })
    @batch_id = batch.id

    render :preview
  end

  # ========================
  # FINALIZE IMPORT
  # ========================
  def create
    batch_id = params[:batch_id]
    batch = ImportBatch.find_by(id: batch_id)

    return redirect_to root_path, alert: "Import batch not found. Please upload again." unless batch

    rows = batch.payload["rows"] || []
    return redirect_to root_path, alert: "Nothing to import." if rows.empty?

    imported = 0
    skipped = 0
    errors  = []

    ActiveRecord::Base.transaction do
      rows.each do |r|
        begin
          property = Property.find_or_create_by!(
            name: r["building_name"],
            address: r["full_address"]
          )

          if r["unit"].present?
            Unit.find_or_create_by!(
              property_id: property.id,
              number: r["unit"]
            )
          end

          imported += 1
        rescue ActiveRecord::RecordNotUnique
          skipped += 1
        rescue => e
          errors << "#{r["full_address"]}: #{e.message}"
        end
      end
    end

    batch.destroy

    @imported = imported
    @skipped  = skipped
    @errors   = errors

    render :finalize
  end

  private

  def normalize_state(input)
    return nil if input.blank?

    upper = input.upcase
    return US_STATES[upper] if US_STATES.key?(upper)

    titled = input.titleize
    return titled if US_STATES.value?(titled)

    nil
  end

  def build_address_display(street, city, state, zip, unit)
    parts = []
    parts << street if street.present?

    city_state = [city, state].reject(&:blank?).join(", ")
    city_state_zip = zip.present? ? "#{city_state} #{zip}".strip : city_state
    parts << city_state_zip if city_state_zip.present?

    result = parts.join(", ")
    result = "Unknown address" if result.blank?
    result += " Unit #{unit}" if unit.present?
    result
  end

end
