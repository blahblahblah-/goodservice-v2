import React from 'react';
import { Segment, Header, Button, Responsive, Statistic } from "semantic-ui-react";
import { withRouter } from 'react-router-dom';

import TrainBullet from './trainBullet';
import TrainModal from './trainModal';
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

  handleClick = () => {
    const { history, train } = this.props
    history.push('/trains/' + train.id);
  }

  renderBullet() {
    const { train, mini } = this.props;
    if (mini) {
      if (train.alternate_name) {
        return (
          <TrainBullet name={train.name} alternateName={train.alternate_name[0]} color={train.color} size='small'
                textColor={train.text_color} style={{ float: 'left' }} />
        );
      }
      return (
        <TrainBullet name={train.name} color={train.color} size='small'
              textColor={train.text_color} style={{ float: 'left' }} />
      );
    }
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
    const { train, trains, selected, mini } = this.props;
    return(
      <TrainModal trainId={train.id} trains={trains} selected={selected} trigger={
        <Segment as={Button} fluid id={"train-" + train.name} onClick={this.handleClick} className='train'>
          { !mini && this.renderInfo() }
          { this.renderBullet() }
        </Segment>
      } />
    )
  }
}
export default withRouter(Train);