# == Schema Information
#
# Table name: courses
#
#  id         :integer          not null, primary key
#  name       :string(255)
#  properties :text(65535)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_courses_on_name  (name)
#
require 'cdo/script_constants'

class Course < ApplicationRecord
  # Some Courses will have an associated Plc::Course, most will not
  has_one :plc_course, class_name: 'Plc::Course'
  has_many :default_course_scripts, -> {where(experiment_name: nil).order('position ASC')}, class_name: 'CourseScript'
  has_many :default_scripts, through: :default_course_scripts, source: :script
  has_many :alternate_course_scripts, -> {where.not(experiment_name: nil)}, class_name: 'CourseScript'

  after_save :write_serialization

  scope :with_associated_models, -> {includes([:plc_course, :default_course_scripts])}

  def skip_name_format_validation
    !!plc_course
  end

  include SerializedToFileValidation
  include SerializedProperties

  serialized_attrs %w(
    teacher_resources
    has_verified_resources
    family_name
    version_year
  )

  def to_param
    name
  end

  def localized_title
    I18n.t("data.course.name.#{name}.title", default: name)
  end

  def localized_assignment_family_title
    I18n.t("data.course.name.#{name}.assignment_family_title", default: localized_title)
  end

  def localized_version_title
    I18n.t("data.course.name.#{name}.version_title", default: version_year)
  end

  def self.file_path(name)
    Rails.root.join("config/courses/#{name}.course")
  end

  def self.load_from_path(path)
    serialization = File.read(path)
    hash = JSON.parse(serialization)

    course = Course.find_or_create_by!(name: hash['name'])
    course.update_scripts(hash['script_names'], hash['alternate_scripts'])
    course.properties = hash['properties']
    course.save!
  rescue Exception => e
    # print filename for better debugging
    new_e = Exception.new("in course: #{path}: #{e.message}")
    new_e.set_backtrace(e.backtrace)
    raise new_e
  end

  # Updates courses.en.json with our new localizeable strings
  # @param name [string] - name of the course being updated
  # @param course_strings[Hash{String => String}]
  def self.update_strings(name, course_strings)
    courses_file = File.expand_path('config/locales/courses.en.json')
    i18n = File.exist?(courses_file) ? JSON.parse(File.read(courses_file)) : {}

    i18n.deep_merge!({'en' => {'data' => {'course' => {'name' => {name => course_strings.to_h}}}}})
    File.write(courses_file, JSON.pretty_generate(i18n))
  end

  def serialize
    JSON.pretty_generate(
      {
        name: name,
        script_names: default_course_scripts.map(&:script).map(&:name),
        alternate_scripts: summarize_alternate_scripts,
        properties: properties
      }.compact
    )
  end

  def summarize_alternate_scripts
    alternates = alternate_course_scripts.all
    return nil if alternates.empty?
    alternates.map do |cs|
      {
        experiment_name: cs.experiment_name,
        alternate_script: cs.script.name,
        default_script: cs.default_script.name
      }
    end
  end

  # This method updates both our localizeable strings related to this course, and
  # the set of scripts that are in the course, then writes out our serialization
  # @param scripts [Array<String>] - Updated list of names of scripts in this course
  # @param alternate_scripts [Array<Hash>] Updated list of alternate scripts in this course
  # @param course_strings[Hash{String => String}]
  def persist_strings_and_scripts_changes(scripts, alternate_scripts, course_strings)
    Course.update_strings(name, course_strings)
    update_scripts(scripts, alternate_scripts) if scripts
    save!
  end

  # @param types [Array<string>]
  # @param links [Array<string>]
  def update_teacher_resources(types, links)
    return if types.nil? || links.nil? || types.length != links.length
    # Only take those pairs in which we have both a type and a link
    self.teacher_resources = types.zip(links).select {|type, link| type.present? && link.present?}
    save!
  end

  def write_serialization
    # Only save non-plc course, and only in LB mode
    return unless Rails.application.config.levelbuilder_mode && !plc_course
    File.write(Course.file_path(name), serialize)
  end

  # @param new_scripts [Array<String>]
  # @param alternate_scripts [Array<Hash>] An array of hashes containing fields
  #   'alternate_script', 'default_script' and 'experiment_name'. Optional.
  def update_scripts(new_scripts, alternate_scripts = nil)
    alternate_scripts ||= []
    new_scripts = new_scripts.reject(&:empty?)
    # we want to delete existing course scripts that aren't in our new list
    scripts_to_delete = default_course_scripts.map(&:script).map(&:name) - new_scripts
    scripts_to_delete -= alternate_scripts.map {|hash| hash['alternate_script']}

    new_scripts.each_with_index do |script_name, index|
      script = Script.find_by_name!(script_name)
      course_script = CourseScript.find_or_create_by!(course: self, script: script) do |cs|
        cs.position = index + 1
      end
      course_script.update!(position: index + 1)
    end

    alternate_scripts.each do |hash|
      alternate_script = Script.find_by_name!(hash['alternate_script'])
      default_script = Script.find_by_name!(hash['default_script'])
      # alternate scripts should have the same position as the script they replace.
      position = default_course_scripts.find_by(script: default_script).position
      course_script = CourseScript.find_or_create_by!(course: self, script: alternate_script) do |cs|
        cs.position = position
        cs.experiment_name = hash['experiment_name']
        cs.default_script = default_script
      end
      course_script.update!(
        position: position,
        experiment_name: hash['experiment_name'],
        default_script: default_script
      )
    end

    scripts_to_delete.each do |script_name|
      script = Script.find_by_name!(script_name)
      CourseScript.where(course: self, script: script).destroy_all
    end
    # Reload model so that default_course_scripts is up to date
    reload
  end

  # Get the assignable info for this course, then update translations
  # @return AssignableInfo
  def assignable_info(user = nil)
    info = ScriptConstants.assignable_info(self)
    # ScriptConstants gives us untranslated versions of our course name, and the
    # category it's in. Set translated strings here
    info[:name] = localized_title
    info[:assignment_family_name] = family_name || name
    info[:assignment_family_title] = localized_assignment_family_title
    info[:version_year] = version_year || ScriptConstants::DEFAULT_VERSION_YEAR
    info[:version_title] = localized_version_title
    # For now, all course versions visible in the UI are stable.
    info[:is_stable] = true
    info[:category] = I18n.t('courses_category')
    info[:script_ids] = user ?
      scripts_for_user(user).map(&:id) :
      default_course_scripts.map(&:script_id)
    info
  end

  # Get the set of valid courses for the dropdown in our sections table. This
  # should be static data for users without any course experiments enabled, but
  # contains localized strings so we can only cache on a per locale basis.
  #
  # @param [User] user Whose experiments to check for possible script substitutions.
  def self.valid_courses(user: nil)
    # Do not cache if the user might have a course experiment enabled which puts them
    # on an alternate script.
    if user && has_any_course_experiments?(user)
      return Course.valid_courses_without_cache(user: user)
    end
    Rails.cache.fetch("valid_courses/#{I18n.locale}") do
      Course.valid_courses_without_cache
    end
  end

  # @param user [User]
  # @returns [Boolean] Whether the user has any experiment enabled which is
  #   associated with an alternate course script.
  def self.has_any_course_experiments?(user)
    Experiment.any_enabled?(user: user, experiment_names: CourseScript.experiments)
  end

  # Get the set of valid courses for the dropdown in our sections table, using
  # any alternate scripts based on any experiments the user belongs to.
  def self.valid_courses_without_cache(user: nil)
    course_infos = Course.
      where(name: ScriptConstants::CATEGORIES[:full_course]).
      map {|course| course.assignable_info(user)}

    # Only return stable course versions.
    # * Currently, all course versions are stable.
    # * In the future, stability will be set as a property by the levelbuilder.
    #
    # Group courses by family when showing multiple versions of each course.
    course_infos.sort_by {|info| [info[:assignment_family_name], info[:version_year]]}
  end

  # Returns whether the course id is valid, even if it is not "stable" yet.
  # @param course_id [String] id of the course we're checking the validity of
  # @return [Boolean] Whether this is a valid course ID
  def self.valid_course_id?(course_id)
    valid_courses.any? {|course| course[:id] == course_id.to_i}
  end

  def summarize(user = nil)
    {
      name: name,
      id: id,
      title: localized_title,
      assignment_family_title: localized_assignment_family_title,
      description_short: I18n.t("data.course.name.#{name}.description_short", default: ''),
      description_student: I18n.t("data.course.name.#{name}.description_student", default: ''),
      description_teacher: I18n.t("data.course.name.#{name}.description_teacher", default: ''),
      scripts: scripts_for_user(user).map do |script|
        include_stages = false
        script.summarize(include_stages).merge!(script.summarize_i18n(include_stages))
      end,
      teacher_resources: teacher_resources,
      has_verified_resources: has_verified_resources?,
      versions: summarize_versions(user)
    }
  end

  def link
    Rails.application.routes.url_helpers.course_path(self)
  end

  def summarize_short
    {
      name: name,
      title: I18n.t("data.course.name.#{name}.title", default: ''),
      description: I18n.t("data.course.name.#{name}.description_short", default: ''),
      link: link,
    }
  end

  # Returns an array of objects showing the name and version year for all courses
  # sharing the family_name of this course, including this one.
  def summarize_versions(user = nil)
    return [] unless family_name
    Course.
      where("properties -> '$.family_name' = ?", family_name).
      map {|c| {name: c.name, version_year: c.version_year, version_title: c.localized_version_title, can_view_version: c.can_view_version?(user)}}.
      sort_by {|info| info[:version_year]}.
      reverse
  end

  # If a user has no experiments enabled, return the default set of scripts.
  # If a user has an experiment enabled corresponding to an alternate script in
  # this course, use the alternate script in place of the default script with
  # the same position.
  # @param user [User]
  # @return [Array<Script>]
  def scripts_for_user(user)
    default_course_scripts.map do |cs|
      select_course_script(user, cs).script
    end
  end

  # Return an alternate course script associated with the specified default
  # course script (or the default course script itself) by evaluating these
  # rules in order:
  #
  # 1. If the user is a teacher, and they have a course experiment enabled,
  # show the corresponding alternate course script.
  #
  # 2. If the user is in a section assigned to this course: show an alternate
  # course script if any section's teacher is in a corresponding course
  # experiment, otherwise show the default course script.
  #
  # 3. If the user is a student and has progress in an alternate course script,
  # show the alternate course script.
  #
  # 4. Otherwise, show the default course script.
  #
  # @param user [User|nil]
  # @param default_course_script [CourseScript]
  # @return [CourseScript]
  def select_course_script(user, default_course_script)
    return default_course_script unless user

    alternates = alternate_course_scripts.where(default_script: default_course_script.script).all

    if user.teacher?
      alternates.each do |cs|
        return cs if SingleUserExperiment.enabled?(user: user, experiment_name: cs.experiment_name)
      end
    end

    course_sections = user.sections_as_student.where(course: self)
    unless course_sections.empty?
      alternates.each do |cs|
        course_sections.each do |section|
          return cs if SingleUserExperiment.enabled?(user: section.teacher, experiment_name: cs.experiment_name)
        end
      end
      return default_course_script
    end

    if user.student?
      alternates.each do |cs|
        # include hidden scripts when iterating over user scripts.
        user.user_scripts.each do |us|
          return cs if cs.script == us.script
        end
      end
    end

    default_course_script
  end

  # @param user [User]
  # @return [String] URL to the course the user should be redirected to.
  def redirect_to_course_url(user)
    # Only redirect students.
    return nil unless user && user.student?
    # No redirect unless user is allowed to view this course version, they are not assigned to the course,
    # and it is versioned.
    return nil unless can_view_version?(user) && !user.assigned_course?(self) && version_year

    # Redirect user to the latest assigned course in this course family,
    # if one exists and it is newer than the current course.
    latest_assigned_version = Course.latest_assigned_version(family_name, user)
    latest_assigned_version_year = latest_assigned_version&.version_year
    return nil unless latest_assigned_version_year && latest_assigned_version_year > version_year
    latest_assigned_version.link
  end

  # @param user [User]
  # @return [Boolean] Whether the user can view the course.
  def can_view_version?(user = nil)
    latest_course_version = Course.latest_version(family_name)
    is_latest = latest_course_version == self

    # All users can see the latest course version.
    return true if is_latest

    # Restrictions only apply to students and logged out users.
    return false if user.nil?
    return true unless user.student?

    # A student can view the course version if they are assigned to it or they have progress in it.
    user.section_courses.include?(self) || has_progress?(user)
  end

  # @param family_name [String] The family name for a course family.
  # @return [Course] Returns the latest version in a course family.
  # TODO: (madelynkasula) Refactor to latest_stable_version once properties[:is_stable] is implemented for courses.
  def self.latest_version(family_name)
    return nil unless family_name.present?

    Course.
      # select only courses in the same course family.
      where("properties -> '$.family_name' = ?", family_name).
      # order by version year.
      order("properties -> '$.version_year' DESC")&.
      first
  end

  # @param family_name [String] The family name for a course family.
  # @param user [User]
  # @return [Course] Returns the latest version in a course family that the user is assigned to.
  def self.latest_assigned_version(family_name, user)
    return nil unless family_name && user
    assigned_course_ids = user.section_courses.pluck(:id)

    Course.
      # select only courses assigned to this user.
      where(id: assigned_course_ids).
      # select only courses in the same course family.
      where("properties -> '$.family_name' = ?", family_name).
      # order by version year.
      order("properties -> '$.version_year' DESC")&.
      first
  end

  # @param user [User]
  # @return [Boolean] Whether the user has progress in this course.
  def has_progress?(user)
    return nil unless user
    user_script_ids = user.user_scripts.pluck(:script_id)
    course_scripts_with_progress = default_course_scripts.where('course_scripts.script_id' => user_script_ids)

    course_scripts_with_progress.count > 0
  end

  # @param user [User]
  # @return [Boolean] Whether the user has progress on another version of this course.
  def has_older_version_progress?(user)
    return nil unless user && family_name && version_year
    user_script_ids = user.user_scripts.pluck(:script_id)

    Course.
      joins(:default_course_scripts).
      # select only courses in the same course family.
      where("properties -> '$.family_name' = ?", family_name).
      # select only older versions
      where("properties -> '$.version_year' < ?", version_year).
      # exclude the current course.
      where.not(id: id).
      # select only courses with scripts which the user has progress in.
      where('course_scripts.script_id' => user_script_ids).
      count > 0
  end

  # returns whether a script in this course has version_warning_dismissed.
  def has_dismissed_version_warning?(user)
    return nil unless user
    script_ids = default_scripts.pluck(:id)
    user.
      user_scripts.
      where(script_id: script_ids).
      select(&:version_warning_dismissed).
      any?
  end

  @@course_cache = nil
  COURSE_CACHE_KEY = 'course-cache'.freeze

  def self.clear_cache
    raise "only call this in a test!" unless Rails.env.test?
    @@course_cache = nil
    Rails.cache.delete COURSE_CACHE_KEY
  end

  def self.should_cache?
    Script.should_cache?
  end

  # generates our course_cache from what is in the Rails cache
  def self.course_cache_from_cache
    # make sure possible loaded objects are completely loaded
    [CourseScript, Plc::Course].each(&:new)
    Rails.cache.read COURSE_CACHE_KEY
  end

  def self.course_cache_from_db
    {}.tap do |cache|
      Course.with_associated_models.find_each do |course|
        cache[course.name] = course
        cache[course.id.to_s] = course
      end
    end
  end

  def self.course_cache_to_cache
    Rails.cache.write(COURSE_CACHE_KEY, course_cache_from_db)
  end

  def self.course_cache
    return nil unless should_cache?
    @@course_cache ||=
      course_cache_from_cache || course_cache_from_db
  end

  def self.get_without_cache(id_or_name)
    # a bit of trickery so we support both ids which are numbers and
    # names which are strings that may contain numbers (eg. 2-3)
    find_by = (id_or_name.to_i.to_s == id_or_name.to_s) ? :id : :name
    # unlike script cache, we don't throw on miss
    Course.find_by(find_by => id_or_name)
  end

  def self.get_from_cache(id_or_name)
    return get_without_cache(id_or_name) unless should_cache?

    course_cache.fetch(id_or_name.to_s) do
      # Populate cache on miss.
      course_cache[id_or_name.to_s] = get_without_cache(id_or_name)
    end
  end
end
