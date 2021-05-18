class Scheduled::Stop < ActiveRecord::Base
  has_many :stop_times, foreign_key: "stop_internal_id", primary_key: "internal_id"

  PREFIX_ABBREVIATIONS = {
    "st" => "saint",
    "ft" => "fort",
  }

  ABBREVIATIONS = {
    "&" => "and",
    "n" => "north",
    "ne" => "northeast",
    "nw" => "northwest",
    "e" => "east",
    "s" => "south",
    "se" => "southeast",
    "sw" => "southwest",
    "w" => "west",
    "lex" => "lexington",
    "st" => "street",
    "sts" => "streets",
    "av" => "avenue",
    "ave" => "avenue",
    "avs" => "avenues",
    "rd" => "road",
    "dr" => "drive",
    "ln" => "lane",
    "blvd" => "boulevard",
    "pk" => "park",
    "sq" => "square",
    "pkwy" => "parkway",
    "hts" => "heights",
    "ctr" => "center",
    "tpke" => "turnpike",
    "jct" => "junction",
    "ext" => "extension",
    "pl" => "place",
  }

  def normalized_full_name(separator: "")
    secondary_name ? "#{self.class.normalized_partial_name(stop_name)} #{separator} #{self.class.normalized_partial_name(secondary_name)}" : self.class.normalized_partial_name(stop_name)
  end

  def normalized_name
    self.class.normalized_partial_name(stop_name)
  end

  def self.normalized_partial_name(name)
    array = name.downcase.split(" - ")
    str = array.map { |s|
      if PREFIX_ABBREVIATIONS[s[0...2]] && s[2] == ' '
        s.sub(s[0...2], PREFIX_ABBREVIATIONS[s[0...2]])
      else
        s
      end
    }.join(" ")

    ABBREVIATIONS.each do |k, v|
      str.gsub!(/\b#{k}\b/, v)
    end
    str.gsub(/[^a-zA-Z0-9 ]/, " ").gsub(/\s\s+/, ' ').gsub(/([0-9]+)/) {|n| "#{n}#{n.to_i.ordinal}" }
  end
end