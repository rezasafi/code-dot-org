/* global React, dashboard */

var STAGE_PROGRESS_TYPE = require('./stage_progress_type');
var StageProgress = require('./stage_progress');

/**
 * Stage progress component used in level header and course overview.
 */
var CourseProgressRow = React.createClass({
  propTypes: {
    stage: React.PropTypes.shape({
      name: React.PropTypes.string,
      lesson_plan_html_url: React.PropTypes.string,
      levels: STAGE_PROGRESS_TYPE
    })
  },

  render: function () {
    var stage = this.props.stage;

    return (
      <div className='game-group'>
        <div className='stage'>
          {stage.title}
          <div className='stage-lesson-plan-link' style={{display: 'none'}}>
            <a target='_blank' href={stage.lesson_plan_html_url}>
              {dashboard.i18n.t('view_lesson_plan')}
            </a>
          </div>
        </div>
        <StageProgress levels={stage.levels} largeDots={true} />
      </div>
    );
  }
});
module.exports = CourseProgressRow;
