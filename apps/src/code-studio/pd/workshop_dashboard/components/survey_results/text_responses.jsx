import React, {PropTypes} from 'react';
import {Well} from 'react-bootstrap';
import _ from 'lodash';

export default class TextResponses extends React.Component {
  static propTypes = {
    question: PropTypes.string.isRequired,
    answers: PropTypes.oneOf(
      PropTypes.arrayOf(PropTypes.string),
      PropTypes.objectOf(PropTypes.arrayOf(PropTypes.string))
    ).isRequired,
    showAverage: PropTypes.boolean
  };

  renderResponseBullets() {
    if (Array.isArray(this.props.answers)) {
      let answers = this.props.answers.map((answer, i) => this.renderBullet(answer, i));

      if (this.props.showAverage) {
        let average = this.computeAverageForAnswers(this.props.answers);
        answers.unshift((
          <li>
            Average: {average}
          </li>
        ));
      }

      return answers;
    } else {
      return Object.keys(this.props.answers).map((facilitator_name, i) => {
        let answers = this.props.answers[facilitator_name].map((feedback, j) => this.renderBullet(feedback, j));
        if (this.props.showAverage) {
          let average = this.computeAverageForAnswers(this.props.answers[facilitator_name]);
          answers.unshift((
            <li>
              Average: {average}
            </li>
          ));
        }

        return (
          <li key={i}>
            {facilitator_name}
            <ul>
              {answers}
            </ul>
          </li>
        );
      });
    }
  }

  computeAverageForAnswers(answers) {
    let numericAnswers = answers.filter(answer => !isNaN(Number(answer)));

    return (numericAnswers.reduce((sum, answer) => {
      let x = parseInt(answer);
      if (x > 0) {
        return sum + x;
      } else {
        return sum;
      }
    }, 0) / numericAnswers.length).toFixed(2);
  }

  renderBullet(text, key) {
    const trimmedText = _.trim(text);
    if (trimmedText) {
      return (
        <li key={key}>
          {trimmedText}
        </li>
      );
    }
  }

  render() {
    return (
      <Well>
        <b>
          {this.props.question}
        </b>
        {this.renderResponseBullets()}
      </Well>
    );
  }
}
