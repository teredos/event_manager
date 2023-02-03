# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def clean_phone_number(number)
  number = number.delete('^0-9')
  if number.length < 10 || number.length > 11
    'Phone number invalid.'
  elsif number.length == 11
    if number[0] == '1'
      number.slice!(0)
      number
    else
      'Phone number invalid.'
    end
  else
    number
  end
end

def collect_regdate(date)
  date[0] = date[0].split('/')
  date[1] = date[1].split(':')
  Time.new("20#{date[0][2]}", date[0][0], date[0][1], date[1][0], date[1][1])
end

def order_reg_hours(hours)
  hours.sort_by { |hour| hours.count(hour) }.reverse.uniq
end

def order_reg_days(days)
  days.sort_by { |day| days.count(day) }.reverse.uniq
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter
register_hours = []
register_days = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  phone_number = clean_phone_number(row[:homephone])
  register_date = collect_regdate(row[:regdate].split)
  register_hours.push(register_date.hour)
  register_days.push(register_date.wday)

  zipcode = clean_zipcode(row[:zipcode])

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

ordered_reg_hours = order_reg_hours(register_hours)
puts "In order, the most common register hours are #{ordered_reg_hours.join(', ')}. (24-hour time format)"
ordered_reg_days = order_reg_days(register_days)
puts "In order, the most common register days are #{ordered_reg_days.join(', ')}. (0-6, Sunday is 0)"