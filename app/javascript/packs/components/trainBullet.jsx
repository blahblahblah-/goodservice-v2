import React from 'react';
import { Segment, Header } from "semantic-ui-react";
import { Link } from "react-router-dom";

import './trainBullet.scss';

class TrainBullet extends React.Component {
  name() {
    const name = this.props.name;
    return name.endsWith("X") ? name[0] : name;
  }

  classNames() {
    const { size, name, directions } = this.props;
    const directionClass = (directions && directions.length === 1) ? (directions[0] === 'north' ? 'uptown-only' : 'downtown-only') : ''
    const fontStretchClass = name.length > 2 ? ' condensed' : '';
    if (size === 'small') {
      return name.endsWith("X") ? 'small route diamond' : 'small route bullet ' + directionClass + fontStretchClass;
    } else if (size === 'medium') {
      return name.endsWith("X") ? 'medium route diamond' : 'medium route bullet ' + directionClass + fontStretchClass;
    }
    return name.endsWith("X") ? 'route diamond' : 'route bullet' + directionClass + fontStretchClass;
  }

  innerClassNames() {
    return this.props.name.endsWith("X") ? 'diamond-inner' : ''
  }

  style() {
    const { style, color, textColor, size, name, alternateName } = this.props;
    let nameLength = name.length + (alternateName?.length || 0);
    let styleHash = {
      ...style,
      backgroundColor: `${color}`
    };

    if (textColor) {
      styleHash.color = `${textColor}`;
    }

    if (size === 'small' && nameLength > 2) {
      styleHash.letterSpacing = '-.06em';
    }

    return styleHash;
  }

  innerStyle() {
    const { name, directions, color, textColor, size, alternateName } = this.props;
    let nameLength = name.length + (alternateName?.length || 0);
    if (!name.endsWith("X") && directions && directions.length === 1 && textColor && textColor.toUpperCase() !== '#FFFFFF') {
      return { WebkitTextStroke: `0.5px ${color}` }
    }
    if (size === 'small' && nameLength > 2) {
      return { fontSize: '.9em' };
    }
  }

  render() {
    const { link, id, linkedView, alternateName } = this.props;
    const view = linkedView && '/' + linkedView || ""
    if (link) {
      return(
        <Link to={'/trains/' + id + view}>
          <div className={this.classNames()} style={this.style()}>
            <div className={this.innerClassNames()} style={this.innerStyle()}>{this.name()}<sup>{alternateName}</sup></div>
          </div>
        </Link>
      )
    } else {
      return(
        <div className={this.classNames()} style={this.style()}>
          <div className={this.innerClassNames()} style={this.innerStyle()}>{this.name()}<sup>{alternateName}</sup></div>
        </div>
      )
    }
  }
}
export default TrainBullet