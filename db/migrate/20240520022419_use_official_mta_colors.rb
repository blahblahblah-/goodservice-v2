class UseOfficialMtaColors < ActiveRecord::Migration[7.1]
  def change
    color_map = {
      '1' => 'ee352e',
      '2' => 'ee352e',
      '3' => 'ee352e',
      '4' => '00933c',
      '5' => '00933c',
      '6' => '00933c',
      '6X' => '00933c',
      '7' => 'b933ad',
      '7X' => 'b933ad',
      'GS' => '6d6e71',
      'A' => '2850ad',
      'B' => 'ff6319',
      'C' => '2850ad',
      'D' => 'ff6319',
      'E' => '2850ad',
      'F' => 'ff6319',
      'FX' => 'ff6319',
      'FS' => '6d6e71',
      'G' => '6cbe45',
      'J' => '996633',
      'L' => 'a7a9ac',
      'M' => 'ff6319',
      'N' => 'fccc0a',
      'Q' => 'fccc0a',
      'R' => 'fccc0a',
      'H' => '6d6e71',
      'W' => 'fccc0a',
      'Z' => '996633',
      'SI' => '00396a',
    }
    color_map.each do |route_id, color|
      route = Scheduled::Route.find_by!(internal_id: route_id)
      route.color = color
      route.save!
    end
  end
end
