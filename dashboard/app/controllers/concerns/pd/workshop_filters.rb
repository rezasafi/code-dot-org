# Controller concern for common Pd::Workshop loading and filtering methods
# To use, include in a controller and call the desired method.
module Pd::WorkshopFilters
  extend ActiveSupport::Concern

  # Query by either:
  #   schedule - the workshop's scheduled start date (date of first session)
  #   end - the date the workshop was ended
  QUERY_BY_SCHEDULE = 'schedule'
  QUERY_BY_END = 'end'

  # Currently only csf is needed. This can be extended in the future.
  COURSE_MAP = {
    csf: Pd::Workshop::COURSE_CSF
  }.stringify_keys.freeze

  # Loads workshops that have ended, filtered based on query params:
  #  - end_date
  #  - start_date
  #  - query_by: 'schedule' or 'end', determines how start_date and end_date are used
  #  - course: null (all), 'csf', or '-csf' (not CSF)
  def load_filtered_ended_workshops
    # Default to the last week, by schedule
    end_date = params[:end] || Date.today
    start_date = params[:start] || end_date - 1.week
    query_by = params[:query_by] || QUERY_BY_SCHEDULE
    course = params[:course]

    workshops = Pd::Workshop.in_state(::Pd::Workshop::STATE_ENDED)
    unless current_user.admin?
      workshops = workshops.organized_by current_user
    end

    # optional '-' (meaning not) followed by a course name
    if course && (match = /^(-)?(.+)$/.match course)
      course_name = COURSE_MAP[match[2]]
      if match[1]
        workshops = workshops.where.not(course: course_name)
      else
        workshops = workshops.where(course: course_name)
      end
    end

    if query_by == QUERY_BY_END
      workshops = workshops.end_on_or_after(start_date).end_on_or_before(end_date)
    else # assume by schedule
      workshops = workshops.start_on_or_after(start_date).start_on_or_before(end_date)
    end

    workshops
  end

  # Apply filters to a set of workshops based on query params. All filters are optional:
  # - state
  # - start (first session on or after)
  # - end (first session on or before)
  # - course
  # - organizer (id)
  # - date_order ('asc' or 'desc', otherwise default to 'asc')
  # Most fields, if incorrect will simply yield an empty result set
  # However date fields are verified and an ArgumentError will be raised if they're invalid.
  # @param workshops [Pd::Workshop::ActiveRecord_Relation] workshop query to filter
  # raises [ArgumentError] when date params are invalid
  # returns [Pd::Workshop::ActiveRecord_Relation] filtered workshop query.
  # Note the filters won't actually be run in SQL until the results are examined.
  def filter_workshops(workshops)
    filter_params.tap do |params|
      workshops = workshops.in_state(params[:state], error_on_bad_state: false) if params[:state]
      workshops = workshops.start_on_or_after(ensure_date(params[:start])) if params[:start]
      workshops = workshops.start_on_or_before(ensure_date(params[:end])) if params[:end]
      workshops = workshops.where(course: params[:course]) if params[:course]
      workshops = workshops.where(organizer: params[:organizer]) if params[:organizer]
      workshops = workshops.order_by_start(desc: params[:date_order].downcase == 'desc') if params[:date_order]
    end

    workshops
  end

  # Permitted params used in #filter_workshops
  def filter_params
    params.permit(
      :state,
      :start,
      :end,
      :course,
      :organizer,
      :date_order
    )
  end

  private

  # Verifies a date string is valid
  # param @date_str [String] the string to verify
  # raises [ArgumentError] if the date string is invalid
  # returns [String] the original value
  def ensure_date(date_str)
    # will raise ArgumentError if it's not a valid date string
    DateTime.parse(date_str)
    date_str
  end
end
