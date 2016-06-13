import React from 'react';
import Radium from 'radium';
import { connect } from 'react-redux';

import { levelProgressShape } from './types';
import { saveAnswersAndNavigate } from '../../levels/saveAnswers';
import color from '../../color';

const dotSize = 24;
const styles = {
  dot: {
    puzzle: {
      display: 'inline-block',
      width: dotSize,
      height: dotSize,
      fontSize: 14,
      textAlign: 'center',
      lineHeight: dotSize + 'px',
      borderRadius: dotSize,
      borderWidth: 2,
      borderStyle: 'solid',
      borderColor: color.lighter_gray,
      margin: '0 2px',
      transition: 'background-color .2s ease-out, border-color .2s ease-out, color .2s ease-out',
      ':hover': {
        textDecoration: 'none',
        color: color.white,
        backgroundColor: color.level_current
      }
    },
    unplugged: {
      width: 'auto',
      fontSize: 13,
      padding: '0 10px'
    },
    assessment: {
      borderColor: color.assessment
    },
    small: {
      width: 7,
      height: 7,
      borderRadius: 7,
      lineHeight: 'inherit',
      fontSize: 0
    },
    overview: {
      height: 30,
      width: 30,
      margin: '2px 4px',
      fontSize: 16,
      lineHeight: '32px'
    },
    icon: {
      borderColor: 'transparent',
      fontSize: 24,
      verticalAlign: -4,
      color: color.white,
      textShadow: `
        ${color.lighter_gray} 0 1px,
        ${color.lighter_gray} 1px 1px,
        ${color.lighter_gray} 1px 0px,
        ${color.lighter_gray} 1px -1px,
        ${color.lighter_gray} 0 -1px,
        ${color.lighter_gray} -1px -1px,
        ${color.lighter_gray} -1px 0,
        ${color.lighter_gray} -1px 1px`,
      ':hover': {
        color: color.white,
        backgroundColor: 'transparent'
      }
    },
    icon_small: {
      width: 9,
      height: 9,
      borderWidth: 0,
      fontSize: 10,
      verticalAlign: 2
    },
    icon_complete: {
      color: color.light_gray,
      textShadow: `
        ${color.white} 0 1px,
        ${color.white} 1px 1px,
        ${color.white} 1px 0px,
        ${color.white} 1px -1px,
        ${color.white} 0 -1px,
        ${color.white} -1px -1px,
        ${color.white} -1px 0,
        ${color.white} -1px 1px`,
      ':hover': {
        color: color.light_gray
      }
    }
  },
  status: {
    submitted: {
      color: color.white,
      backgroundColor: color.level_submitted
    },
    perfect: {
      color: color.white,
      backgroundColor: color.level_perfect
    },
    passed: {
      color: color.white,
      backgroundColor: color.level_passed
    },
    attempted: {
      color: color.charcoal,
      backgroundColor: color.level_attempted
    },
    not_tried: {
      color: color.charcoal,
      backgroundColor: color.level_not_tried
    },
    review_rejected: {
      color: color.white,
      backgroundColor: color.level_review_rejected
    },
    review_accepted: {
      color: color.white,
      backgroundColor: color.level_review_accepted
    }
  }
};

function dotClicked(url, e) {
  e.preventDefault();
  saveAnswersAndNavigate(url);
}

/**
 * Stage progress component used in level header and course overview.
 */
export const ProgressDot = React.createClass({
  propTypes: {
    level: levelProgressShape.isRequired,
    currentLevelId: React.PropTypes.string,
    courseOverviewPage: React.PropTypes.bool,
    saveAnswersBeforeNavigation: React.PropTypes.bool.isRequired
  },

  render() {
    const level = this.props.level;
    const uid = level.uid || level.id.toString();

    const isUnplugged = isNaN(level.title);
    const showUnplugged = isUnplugged && (this.props.courseOverviewPage || uid === this.props.currentLevelId);
    const smallDot = !this.props.courseOverviewPage && uid !== this.props.currentLevelId;
    const showLevelName = level.kind === 'named_level' && this.props.courseOverviewPage;

    return (
      <a
        href={level.url}
        onClick={this.props.saveAnswersBeforeNavigation && dotClicked.bind(null, level.url)}
        style={[showLevelName && {display: 'block'}]
      }>
        {level.icon ?
          <i className={`fa ${level.icon}`} style={[
            styles.dot.puzzle,
            this.props.courseOverviewPage && styles.dot.overview,
            styles.dot.icon,
            smallDot && styles.dot.icon_small,
            level.status && level.status !== 'not_tried' && styles.dot.icon_complete
          ]} /> :
          <div style={[
            styles.dot.puzzle,
            this.props.courseOverviewPage && styles.dot.overview,
            smallDot && styles.dot.small,
            level.kind === 'assessment' && styles.dot.assessment,
            uid === this.props.currentLevelId && {borderColor: color.level_current},
            showUnplugged && styles.dot.unplugged,
            styles.status[level.status || 'not_tried']
          ]} className={`level-${level.id}`}>{level.kind === 'named_level' ? '\u00a0' : level.title}</div>
        }
        {showLevelName &&
          <span style={{marginLeft: 5, color: color.purple}}>{level.name}</span>
        }
      </a>
    );
  }
});
export default connect(state => ({
  currentLevelId: state.currentLevelId,
  saveAnswersBeforeNavigation: state.saveAnswersBeforeNavigation
}))(Radium(ProgressDot));
