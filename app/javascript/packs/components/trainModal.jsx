import React from 'react';
import { Modal, Dimmer, Loader, Grid, Menu, Header } from "semantic-ui-react";
import { withRouter, Redirect, HashRouter, Switch, Route, NavLink } from 'react-router-dom';
import { Helmet } from "react-helmet";

import TrainBullet from './trainBullet';
import TrainModalOverviewPane from './trainModalOverviewPane';
import TrainModalDirectionPane from './trainModalDirectionPane';
import TripModal from './tripModal';
import { formatStation, routingHash } from './utils';

import './trainModal.scss'

const API_URL_PREFIX = '/api/routes/';

class TrainModal extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
    };
  }

  componentDidUpdate(prevProps) {
    const { selected } = this.props;
    if (prevProps.selected === selected) {
      return;
    }
    if (selected) {
      this.fetchData();
      this.timer = setInterval(() => this.fetchData(), 15000);
    } else {
      clearInterval(this.timer);
    }
  }

  componentDidMount() {
    const { selected } = this.props;
    if (selected) {
      this.fetchData();
      this.timer = setInterval(() => this.fetchData(), 15000);
    }
  }

  componentWillUnmount() {
    clearInterval(this.timer);
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

  render() {
    const { train, timestamp } = this.state;
    const { trains, trigger, selected, match, stations, location } = this.props;
    const title = `goodservice.io - ${train?.alternate_name ? `S - ${train?.alternate_name}` : train?.name} Train`;

    if (match.params.direction && !['N', 'S'].includes(match.params.direction)) {
      return (<Redirect to={`/trains/${match.params.id}`} />);
    }

    let tripModal = null;
    let trip = null;
    let className = 'train-modal';
    if (train && match.params.id === train.id && match.params.direction && match.params.tripId) {
      const direction = match.params.direction === 'N' ? 'north' : 'south';
      if (train.trips[direction]) {
        const routingKey = Object.keys(train.trips[direction]).find((routingKey) => {
          trip = train.trips[direction][routingKey].find((trip) => {
            return trip.id === match.params.tripId;
          });
          return trip;
        });
        if (!trip) {
          return (<Redirect to={`/trains/${train.id}`} />);
        }
        const routing = train.actual_routings[direction].find((r) => routingHash(r) === routingKey);
        tripModal = (
          <TripModal train={train} trains={trains} selectedTrip={trip} stations={stations} direction={direction} routing={routing} />
        );
        className = 'train-modal dimmable dimmed blurring';
      }
    }
    return (
      <Modal basic size='fullscreen' open={selected} closeIcon dimmer='blurring'
         onClose={this.handleOnClose} closeOnDocumentClick closeOnDimmerClick className={className}>
        {
          !train &&
          <Dimmer active>
            <Loader inverted></Loader>
          </Dimmer>
        }
        {
          tripModal
        }
        {
          train &&
            <React.Fragment>
              <Helmet>
                <title>{title}</title>
                <meta property="og:title" content={title} />
                <meta name="twitter:title" content={title} />
                <meta property="og:url" content={`https://www.goodservice.io/trains/${train.id}`} />
                <meta name="twitter:url" content={`https://www.goodservice.io/trains/${train.id}`} />
              </Helmet>
              <Modal.Header>
                <Grid>
                  <Grid.Row>
                    <Grid.Column width={4} textAlign='center'>
                      <TrainBullet name={train.name} color={train.color}
                        textColor={train.text_color} style={{display: "inline-block"}} size='large' />
                      <p>{train.alternate_name}</p>
                    </Grid.Column>
                    <Grid.Column verticalAlign='middle' width={12}>
                      <Menu widths={3} inverted className='header-menu' stackable>
                        <Menu.Item name='overview' as={NavLink} exact to={`/trains/${train.id}`} >
                          Overview
                        </Menu.Item>
                        <Menu.Item name='N' className={this.noService('north') ? 'no-service' : ''} as={NavLink} exact to={`/trains/${train.id}/N`}>
                          To {this.formatDestinations(train.destinations?.north)}
                        </Menu.Item>
                        <Menu.Item name='S'  className={this.noService('south') ? 'no-service' : ''} as={NavLink} exact to={`/trains/${train.id}/S`}>
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
                  match.params.direction === 'N' &&
                  <TrainModalDirectionPane train={train} trains={trains} stations={stations} direction='north' />
                }
                {
                  match.params.direction === 'S' &&
                  <TrainModalDirectionPane train={train} trains={trains} stations={stations} direction='south' />
                }
                {
                  !match.params.direction &&
                  <TrainModalOverviewPane train={train} trains={trains} stations={stations} />
                }
                  <Header inverted as='h5'>
                    View on a map at <a href={`https://www.theweekendest.com/trains/${train.id}`} target="_blank">The Weekendest</a>.<br />
                    Last updated {timestamp && (new Date(timestamp * 1000)).toLocaleTimeString('en-US')}.
                  </Header>
                </Modal.Description>
              </Modal.Content>
            </React.Fragment>
        }
      </Modal>
    );
  }
}

export default withRouter(TrainModal);