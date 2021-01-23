import React from 'react';
import { Modal, Dimmer, Loader, Grid, Menu, Header } from "semantic-ui-react";
import { withRouter } from 'react-router-dom';

import TrainBullet from './trainBullet';
import TrainModalOverallPane from './trainModalOverallPane';
import TrainModalDirectionPane from './trainModalDirectionPane';
import { formatStation } from './utils';

import './trainModal.scss'

const API_URL_PREFIX = '/api/routes/';

class TrainModal extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      activeMenuItem: 'overall',
    };
  }

  componentDidUpdate(prevProps) {
    const { selected } = this.props;
    if (prevProps.selected === selected) {
      return;
    }
    if (selected) {
      this.fetchData();
      this.timer = setInterval(() => this.fetchData(), 30000);
    } else {
      clearInterval(this.timer);
    }
  }

  componentDidMount() {
    const { selected } = this.props;
    if (selected) {
      this.fetchData();
      this.timer = setInterval(() => this.fetchData(), 30000);
    }
  }

  fetchData() {
    const { trainId } = this.props;

    if (!trainId) {
      return;
    }

    fetch(`${API_URL_PREFIX}${trainId}`)
      .then(response => response.json())
      .then(data => this.setState({ train: data, timestamp: data.timestamp}))
  }

  formatDestinations(destinations) {
    if (!destinations || destinations.length < 1) {
      return '--';
    }
    return destinations.map(s=><React.Fragment key={s}>{formatStation(s)}<br/></React.Fragment>);
  }

  noService(direction) {
    const { train } = this.state;
    if (['No Service', 'Not Scheduled'].includes(train.status)) {
      return true;
    }
    if (!train.direction_statuses || !train.direction_statuses[direction] || ['No Service', 'Not Scheduled'].includes(train.direction_statuses[direction])) {
      return true;
    }

    return false;
  }

  handleOnClose = () => {
    const { history } = this.props;
    return history.push('/');
  };

  handleItemClick = (_, { name }) => this.setState({ activeMenuItem: name })

  render() {
    const { train, activeMenuItem, timestamp } = this.state;
    const { trains, trigger, selected } = this.props;
    return (
      <Modal basic size='large' trigger={trigger} open={selected} closeIcon dimmer='blurring'
         onClose={this.handleOnClose} closeOnDocumentClick closeOnDimmerClick className='train-modal'>
        {
          !train &&
          <Dimmer active>
            <Loader inverted></Loader>
          </Dimmer>
        }
        {
          train &&
            <>
              <Modal.Header>
                <Grid>
                  <Grid.Row>
                    <Grid.Column width={4}>
                      <TrainBullet name={train.name} color={train.color}
                        textColor={train.text_color} style={{display: "inline-block"}} size='large' />
                      <p>{train.alternate_name}</p>
                    </Grid.Column>
                    <Grid.Column verticalAlign='middle' width={12}>
                      <Menu widths={3} inverted className='header-menu'>
                        <Menu.Item name='overall' active={activeMenuItem === 'overall'} onClick={this.handleItemClick}>
                          Overall
                        </Menu.Item>
                        <Menu.Item name='north' active={activeMenuItem === 'north'} className={this.noService('north') ? 'no-service' : ''} onClick={this.handleItemClick}>
                          To {this.formatDestinations(train.destinations?.north)}
                        </Menu.Item>
                        <Menu.Item name='south' active={activeMenuItem === 'south'} className={this.noService('south') ? 'no-service' : ''} onClick={this.handleItemClick}>
                          To {this.formatDestinations(train.destinations?.south)}
                        </Menu.Item>
                      </Menu>
                    </Grid.Column>
                  </Grid.Row>
                </Grid>
              </Modal.Header>
              <Modal.Content scrolling>
                <Modal.Description>
                  {
                    activeMenuItem === 'overall' &&
                      <TrainModalOverallPane train={train} trains={trains} />
                  }
                  {
                    activeMenuItem !== 'overall' &&
                      <TrainModalDirectionPane train={train} trains={trains} direction={activeMenuItem} />
                  }
                  <Header inverted as='h5'>
                    Last updated {timestamp && (new Date(timestamp * 1000)).toLocaleTimeString('en-US')}.<br />
                  </Header>
                </Modal.Description>
              </Modal.Content>
            </>
        }
      </Modal>
    );
  }
}

export default withRouter(TrainModal);