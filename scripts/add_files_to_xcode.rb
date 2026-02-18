#!/usr/bin/env ruby
# Usage: ruby scripts/add_files_to_xcode.rb
# Adds any .swift files in the project directory that are not yet
# referenced in the Xcode project to the correct target.
require 'xcodeproj'
require 'pathname'

XCODE_PROJ = 'TheRecruitingCompass/TheRecruitingCompass.xcodeproj'
APP_TARGET = 'TheRecruitingCompass'
TEST_TARGET = 'TheRecruitingCompassTests'
UI_TEST_TARGET = 'TheRecruitingCompassUITests'
SOURCE_ROOT = 'TheRecruitingCompass/TheRecruitingCompass'
TESTS_ROOT = 'TheRecruitingCompass/TheRecruitingCompassTests'
UI_TESTS_ROOT = 'TheRecruitingCompass/TheRecruitingCompassUITests'

project = Xcodeproj::Project.open(XCODE_PROJ)

def all_referenced_paths(project)
  project.files.map(&:real_path).map(&:to_s).to_set
end

def find_or_create_group(project, relative_path)
  parts = relative_path.split('/')
  current = project.main_group
  parts.each do |part|
    child = current.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXGroup) && c.name == part }
    child ||= current.new_group(part)
    current = child
  end
  current
end

def add_file_if_missing(project, file_path, group_path, target)
  referenced = all_referenced_paths(project)
  abs_path = File.expand_path(file_path)
  return if referenced.include?(abs_path)

  group = find_or_create_group(project, group_path)
  file_ref = group.new_reference(abs_path)
  target.add_file_references([file_ref])
  puts "  Added: #{file_path}"
end

app_target = project.targets.find { |t| t.name == APP_TARGET }
test_target = project.targets.find { |t| t.name == TEST_TARGET }
ui_test_target = project.targets.find { |t| t.name == UI_TEST_TARGET }

puts "Scanning for unregistered Swift files..."

# App source files
Dir.glob("#{SOURCE_ROOT}/**/*.swift").each do |file|
  referenced = all_referenced_paths(project)
  abs = File.expand_path(file)
  next if referenced.include?(abs)

  relative_dir = File.dirname(file).sub("#{SOURCE_ROOT}/", '')
  group_parts = relative_dir.split('/')
  group = find_or_create_group(project, group_parts.join('/'))
  file_ref = group.new_reference(abs)
  app_target.add_file_references([file_ref])
  puts "  [App] Added: #{file}"
end

# Test files
Dir.glob("#{TESTS_ROOT}/**/*.swift").each do |file|
  referenced = all_referenced_paths(project)
  abs = File.expand_path(file)
  next if referenced.include?(abs)

  relative_dir = File.dirname(file).sub("#{TESTS_ROOT}/", '')
  group_parts = relative_dir.split('/')
  group = find_or_create_group(project, group_parts.join('/'))
  file_ref = group.new_reference(abs)
  test_target.add_file_references([file_ref])
  puts "  [Tests] Added: #{file}"
end

# UI Test files
Dir.glob("#{UI_TESTS_ROOT}/**/*.swift").each do |file|
  referenced = all_referenced_paths(project)
  abs = File.expand_path(file)
  next if referenced.include?(abs)

  relative_dir = File.dirname(file).sub("#{UI_TESTS_ROOT}/", '')
  group_parts = relative_dir.split('/')
  group = find_or_create_group(project, group_parts.join('/'))
  file_ref = group.new_reference(abs)
  ui_test_target.add_file_references([file_ref])
  puts "  [UITests] Added: #{file}"
end

project.save
puts "\nDone. Run 'git add TheRecruitingCompass/TheRecruitingCompass.xcodeproj/' to stage."
