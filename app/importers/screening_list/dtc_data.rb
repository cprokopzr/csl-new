# frozen_string_literal: true

require "csv"

module ScreeningList
  class DtcData
    include Importable
    include ::VersionableResource

    include ::CanEnsureCsvHeaders
    self.expected_csv_headers = %i(
      corrected_notice corrected_notice_date
      date_of_birth federal_register_notice
      notice_date party_name )

    # We don't group source entries in this importer, but we want
    # to use the generate_id method brought in by this module.
    include ScreeningList::CanGroupRows
    self.group_by = %i(name start_date federal_register_notice)

    include ScreeningList::MakeNameVariants

    ENDPOINT = "https://www.pmddtc.state.gov/sys_attachment.do?sys_id=81d49a191b0f70d0d1f1ea02f54bcb76"

    def import
      @source_information_url = "https://www.pmddtc.state.gov/?id=ddtc_kb_article_page&sys_id=c22d1833dbb8d300d0a370131f9619f0"
      @source_list_url = "https://www.pmddtc.state.gov/?id=ddtc_kb_article_page&sys_id=7188dac6db3cd30044f9ff621f961914"
      @admin_source_list_url = "http://www.pmddtc.state.gov/compliance/debar_admin.html"

      rows = CSV.parse(loaded_resource, headers: true, header_converters: :symbol, encoding: "UTF-8")

      ensure_expected_headers(rows.first)

      entries = rows.map { |row| process_row row.to_h }.compact
      model_class.index(entries)
    end

    private
      def process_row(row)
        doc = {
          name:                    extract_name(row),
          alt_names:               extract_alt_names(row),
          federal_register_notice: (row[:corrected_notice] || row[:federal_register_notice]),
          source:                  model_class.source,
          source_information_url:  @source_information_url,
        }

        make_names(doc)

        doc[:source_list_url] = row[:type] == "Administrative" ? @admin_source_list_url : @source_list_url

        doc[:id] = generate_id(doc)
        sanitize_entry(doc)
      end
      def extract_name(row)
        name = row[:party_name]
        if name.include? "Inc."
          name
        else
          name.sub(/\(.*\)/, "").sub(/(.*),(.*)/, '\2 \1')
        end
      end

      def extract_alt_names(row)
        name = row[:party_name]
        if name.include? "a.k.a."
          name.sub(/.*(\(a.*\))/, '\1').sub("(a.k.a. ", "").sub(")", "").split("; ")
        else
          []
        end
      end
  end
end
