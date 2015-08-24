# encoding: utf-8
require File.expand_path(File.dirname(__FILE__)) + '/../test_helper'

# This file is generated by the Ruby Holiday gem.
#
# Definitions loaded: data/gb.yaml
class GbDefinitionTests < Test::Unit::TestCase  # :nodoc:

  def test_gb
{Date.civil(2008,3,21) => 'Good Friday',
 Date.civil(2008,3,23) => 'Easter Sunday',
 Date.civil(2008,5,5) => 'May Day',
 Date.civil(2008,5,26) => 'Bank Holiday',
 Date.civil(2008,11,5) => 'Guy Fawkes Day',
 Date.civil(2008,12,25) => 'Christmas Day',
 Date.civil(2008,12,26) => 'Boxing Day'}.each do |date, name|
  assert_equal name, (Holidays.on(date, :gb, :informal)[0] || {})[:name]
end

assert_equal 'St. Patrick\'s Day', Date.civil(2008,3,17).holidays(:gb_nir, :informal)[0][:name]
assert_equal 'St. Andrew\'s Day', Date.civil(2008,11,30).holidays(:gb_sct, :informal)[0][:name]

assert_equal 'Christmas Day', Date.civil(2008,12,25).holidays(:gb_, :observed)[0][:name]
assert_equal 'Christmas Day', Date.civil(2009,12,25).holidays(:gb_, :observed)[0][:name]
assert_equal 'Christmas Day', Date.civil(2010,12,27).holidays(:gb_, :observed)[0][:name]

assert_equal 'Boxing Day', Date.civil(2008,12,26).holidays(:gb_, :observed)[0][:name]
assert_equal 'Boxing Day', Date.civil(2009,12,28).holidays(:gb_, :observed)[0][:name]
assert_equal 'Boxing Day', Date.civil(2010,12,28).holidays(:gb_, :observed)[0][:name]
assert_equal 'Boxing Day', Date.civil(2011,12,27).holidays(:gb_, :observed)[0][:name]

assert_equal 'New Year\'s Day', Date.civil(2010,1,1).holidays(:gb, :observed)[0][:name]
assert_equal 'New Year\'s Day', Date.civil(2011,1,3).holidays(:gb, :observed)[0][:name]
assert_equal 'New Year\'s Day', Date.civil(2012,1,2).holidays(:gb, :observed)[0][:name]

assert_equal '2nd January', Date.civil(2010,1,4).holidays(:gb_sct, :observed)[0][:name]
assert_equal '2nd January', Date.civil(2011,1,4).holidays(:gb_sct, :observed)[0][:name]
assert_equal '2nd January', Date.civil(2012,1,3).holidays(:gb_sct, :observed)[0][:name]
assert_equal '2nd January', Date.civil(2013,1,2).holidays(:gb_sct, :observed)[0][:name]
assert_equal '2nd January', Date.civil(2014,1,2).holidays(:gb_sct, :observed)[0][:name]

[:gb_wls, :gb_eng, :gb_nir, :gb_eaw, :gb_].each do |r|
  assert_equal 'Easter Monday', Date.civil(2008,3,24).holidays(r)[0][:name]
  assert_equal 'Bank Holiday', Date.civil(2008,8,25).holidays(r)[0][:name]
end

  end
end
