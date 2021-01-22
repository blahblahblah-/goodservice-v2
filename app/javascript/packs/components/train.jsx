import React from 'react';
import { Segment, Header, Button, Responsive, Statistic } from "semantic-ui-react";
import TrainBullet from './trainBullet';
import { statusColor } from './utils';
import './train.scss';

class Train extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      modelOpen: false
    }
  }

  alternateName() {
    const alternameName = this.props.train.alternate_name;
    if (alternameName) {
      const alt = alternameName.replace("Shuttle", "");
      return (
        <span className='alternate-name'>{alt}</span>
      )
    }
  }

  handleClick = e => {
    const { starredPane, history, showStats, train, location } = this.props
    if (starredPane) {
      history.push('/starred/' + train.id);
    } else if (showStats) {
      history.push(`/trains/${train.id}/stats${location.hash}`);
    } else {
      history.push('/trains/' + train.id);
    }
  }

  renderBullet() {
    const { train } = this.props;
    // if (mini && train.alternate_name) {
    //   return (
    //     <TrainBullet name={train.name} alternateName={train.alternate_name[0]} color={train.color} size={'small'}
    //           textColor={train.text_color} style={{ float: 'left' }} />
    //   )
    // }
    if (train.alternate_name) {
      return (
        <div className='train-bullet'>
          <TrainBullet name={train.name} color={train.color} size={'normal'}
              textColor={train.text_color} />
          <div className='alternate-name'>{this.alternateName()}</div>
        </div>
      )
    }
    return (
      <TrainBullet name={train.name} color={train.color} size='normal'
              textColor={train.text_color} className='train-bullet' />
    )
  }

  renderInfo() {
    const { status } = this.props.train;
    return (
      <div>
        <Header as='h3' floated='right' className='status' inverted color={statusColor(status)}>{ status }</Header>
      </div>
    )
  }

  render() {
    const { train } = this.props;
    // const buttonStyle = {};
    // if (mini) {
    //   buttonStyle.padding = "0";
    //   buttonStyle.border = "none";
    //   buttonStyle.background = "none";
    //   buttonStyle.minWidth = "2em";
    // }
    return(
      <Segment as={Button} fluid id={"train-" + train.name} className='train'>
        { this.renderInfo() }
        { this.renderBullet() }
      </Segment>
    )
  }
}
export default Train;