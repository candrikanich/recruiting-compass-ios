#!/usr/bin/env ruby
# Usage: cd <worktree-root> && ruby scripts/add_files_to_xcode.rb
#
# Adds .swift files that exist on disk but are NOT referenced in the Xcode project.
# Uses filename-based matching (not absolute paths) to work correctly across git worktrees.
#
require 'xcodeproj'
require 'set'

XCODE_PROJ     = 'TheRecruitingCompass/TheRecruitingCompass.xcodeproj'
APP_TARGET     = 'TheRecruitingCompass'
TEST_TARGET    = 'TheRecruitingCompassTests'
UI_TEST_TARGET = 'TheRecruitingCompassUITests'

SOURCE_ROOT    = 'TheRecruitingCompass/TheRecruitingCompass'
TESTS_ROOT     = 'TheRecruitingCompass/TheRecruitingCompassTests'
UI_TESTS_ROOT  = 'TheRecruitingCompass/TheRecruitingCompassUITests'

project = Xcodeproj::Project.open(XCODE_PROJ)

# Collect all basenames already referenced in the project (fast lookup by filename)
referenced_basenames = project.files.map { |f| File.basename(f.path.to_s) }.to_set

def group_for_relative_dir(project, relative_dir)
  parts = relative_dir.split('/').reject(&:empty?)
  current = project.main_group
  parts.each do |part|
    child = current.children.find do |c|
      c.is_a?(Xcodeproj::Project::Object::PBXGroup) && (c.name == part || c.path == part)
    end
    child ||= current.new_group(part, part)
    current = child
  end
  current
end

added = 0

[[SOURCE_ROOT, APP_TARGET], [TESTS_ROOT, TEST_TARGET], [UI_TESTS_ROOT, UI_TEST_TARGET]].each do |root, target_name|
  target = project.targets.find { |t| t.name == target_name }
  unless target
    puts "Warning: target '#{target_name}' not found, skipping."
    next
  end

  Dir.glob("#{root}/**/*.swift").sort.each do |rel_path|
    basename = File.basename(rel_path)
    next if referenced_basenames.include?(basename)

    abs_path = File.expand_path(rel_path)
    relative_dir = File.dirname(rel_path).sub(%r{^#{Regexp.escape(root)}/?}, '')
    group = group_for_relative_dir(project, relative_dir)
    file_ref = group.new_file(abs_path)
    target.add_file_references([file_ref])
    referenced_basenames.add(basename)
    added += 1
    puts "  [#{target_name}] #{rel_path}"
  end
end

if added > 0
  project.save
  puts "\nAdded #{added} file(s). Stage changes with:"
  puts "  git add TheRecruitingCompass/TheRecruitingCompass.xcodeproj/"
else
  puts "All Swift files already registered — no changes needed."
end
