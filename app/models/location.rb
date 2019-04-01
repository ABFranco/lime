class Location < ActiveRecord::Base
  belongs_to :parent, :class_name => "Location"
  has_many :children, :class_name => "Location", :foreign_key => 'parent_id'
  validate :parent_presence

  def self.seed
    location_hashes = [{'location' => 'USA', 'parent' => 'Global'},
                      {'location' => 'California', 'parent' => 'USA'},
                      {'location' => 'Berkeley', 'parent' => 'California'},
                      {'location' => 'Davis', 'parent' => 'California'},
                      {'location' => 'Stanfurd', 'parent' => 'California'},
                      {'location' => 'Siberia', 'parent' => 'Global'}
                  ]
    global = Location.create :val => "Global"
    global.save :validate => false
    location_hashes.each do |location|
      parent = Location.where(:val => location['parent'].to_s).first
      Location.create! :val => location['location'], :parent_id => parent.id
    end
  end

  def parent_presence
    (not parent.blank?) or (val == "Global" and Location.where(:val => "Global").empty?)
  end
end