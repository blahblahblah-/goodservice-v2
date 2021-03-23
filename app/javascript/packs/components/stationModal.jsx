import React from 'react';
import { Modal, Dimmer, Loader, Header, Table, Statistic, Divider, Segment, List } from "semantic-ui-react";
import { withRouter, Link } from 'react-router-dom';
import { Helmet } from "react-helmet";

import TrainBullet from './trainBullet';
import { statusColor, formatStation, formatMinutes } from './utils';
import { accessibilityIcon } from './accessibility.jsx';
import './stationModal.scss';

const API_URL_PREFIX = '/api/stops/';

class StationModal extends React.Component {
  constructor(props) {
    super(props);
    this.state = {};
  }

  componentDidMount() {
    this.fetchData();
    this.timer = setInterval(() => this.fetchData(), 30000);
  }

  componentWillUnmount() {
    clearInterval(this.timer);
  }

  componentDidUpdate(prevProps) {
    const { selectedStation } = this.props;
    if (prevProps.selectedStation === selectedStation) {
      return;
    }
    this.fetchData();
  }

  fetchData() {
    const { selectedStation } = this.props;

    if (!selectedStation) {
      return;
    }

    fetch(`${API_URL_PREFIX}${selectedStation.id}`)
      .then(response => response.json())
      .then(data => this.setState({ station: data, timestamp: data.timestamp}))
  }

  handleOnClose = () => {
    const { history } = this.props;
    return history.push('/');
  };

  renderAccessibilityAdvisories(selectedStation) {
    if (!selectedStation.accessibility || selectedStation.accessibility.advisories.length === 0) {
      return;
    }

    return (
      <div className='accessibility-advisories'>
        {
          selectedStation.accessibility.advisories.map((a, i) => {
            return (
              <Header as='h5' key={i} inverted>Elevator for { a } is out of service.</Header>
            );
          })
        }
        <Header as='h5' inverted>For more info, see <a href='https://new.mta.info/elevator-escalator-status' target='_blank'>mta.info</a>.</Header>
      </div>
    )
  }

  renderTransfers(selectedStation, trains, stations) {
    if (!selectedStation.transfers) {
      return;
    }
    return (
      <React.Fragment>
        <Header as='h4' inverted>Transfers</Header>
        <List divided relaxed selection inverted className='transfers'>
          {
            selectedStation.transfers.map((stationId) => {
              const station = stations[stationId];
              return(
                <List.Item as={Link} key={stationId} className='station-list-item' to={`/stations/${stationId}`}>
                  <List.Content floated='left'>
                    <Header as='h5'>
                      { formatStation(station.name) }
                    </Header>
                  </List.Content>
                  {
                    station.secondary_name &&
                    <List.Content floated='left' className="secondary-name">
                      { station.secondary_name }
                    </List.Content>
                  }
                  {
                    station.accessibility &&
                    <List.Content floated='left'>
                      { accessibilityIcon(station.accessibility) }
                    </List.Content>
                  }
                  <List.Content floated='right'>
                    {
                      Object.keys(station.routes).map((trainId) => {
                        const train = trains[trainId];
                        const directions = station.routes[trainId];
                        return (
                          <TrainBullet id={trainId} key={train.name} name={train.name} color={train.color}
                            textColor={train.text_color} size='small' key={train.id} directions={directions} />
                        )
                      })
                    }
                  </List.Content>
                </List.Item>
              )
            })
          }
        </List>
      </React.Fragment>
    );
  }

  renderDepartureTable(direction, station, trains, stations) {
    const trips = station.upcoming_trips[direction];

    if (!trips) {
      return;
    }

    const currentTime = Date.now() / 1000;
    const destinations = [...new Set(trips.map((t) => t.destination_stop))].map((s) => formatStation(stations[s].name)).sort().join(', ');
    return (
      <React.Fragment>
        <Header as='h4' inverted>To { destinations }</Header>
        <Table fixed inverted unstackable size='small' compact className='trip-table'>
          <Table.Header>
            <Table.Row>
              <Table.HeaderCell rowSpan='2' width={3}>
                Train ID / Destination
              </Table.HeaderCell>
              <Table.HeaderCell colSpan='2'>
                Time Until Departure
              </Table.HeaderCell>
              <Table.HeaderCell rowSpan='2'>
                Current Location
              </Table.HeaderCell>
              <Table.HeaderCell rowSpan='2'>
                Schedule Adherence
              </Table.HeaderCell>
            </Table.Row>
            <Table.Row>
              <Table.HeaderCell width={2}>
                Projected
              </Table.HeaderCell>
              <Table.HeaderCell width={2}>
                Estimated
              </Table.HeaderCell>
            </Table.Row>
          </Table.Header>
          {
            this.renderDepartureTableBody(direction, trips, trains, stations, currentTime)
          }
        </Table>
      </React.Fragment>
    );
  }

  renderDepartureTableBody(direction, trips, trains, stations, currentTime) {
    return (
      <Table.Body>
        {
          trips.map((trip) => {
            const train = trains[trip.route_id];
            const directionKey = direction[0].toUpperCase();
            const delayed = trip.delayed_time > 300;
            const effectiveDelayedTime = Math.max(trip.schedule_discrepancy, 0) + trip.delayed_time;
            const delayedTime = trip.is_delayed ? effectiveDelayedTime : trip.delayed_time;
            const delayInfo = delayed ? `(${trip.is_delayed ? 'delayed' : 'held'} for ${Math.round(delayedTime / 60)} mins)` : '';
            const estimatedTimeUntilUpcomingStop = Math.round((trip.estimated_upcoming_stop_arrival_time - currentTime) / 60);
            const upcomingStopArrivalTime = Math.round((trip.upcoming_stop_arrival_time - currentTime) / 60);
            const estimatedTimeUntilThisStop = Math.round((trip.estimated_current_stop_arrival_time - currentTime) / 60);
            const timeUntilThisStop = Math.round((trip.current_stop_arrival_time - currentTime) / 60);
            const scheduleDiscrepancy = trip.schedule_discrepancy !== null ? Math.round(trip.schedule_discrepancy / 60) : 0;
            return (
              <Table.Row key={trip.id} className={delayed ? 'delayed' : ''}>
                <Table.Cell>
                  <Link to={`/trains/${trip.route_id}/${directionKey}/${trip.id}`}>
                    <TrainBullet id={trip.route_id} name={train.name} color={train.color} textColor={train.text_color} size='small' />
                    {trip.id} to {formatStation(stations[trip.destination_stop].name)} {delayInfo && <Header as='h5' className='delayed-text' inverted color='red'>{delayInfo}</Header> }
                  </Link>
                </Table.Cell>
                <Table.Cell title={new Date(trip.estimated_current_stop_arrival_time * 1000).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit'})}>
                  { formatMinutes(estimatedTimeUntilThisStop, true)}
                </Table.Cell>
                <Table.Cell title={new Date(trip.current_stop_arrival_time * 1000).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit'})}>
                  { formatMinutes(timeUntilThisStop, true)}
                </Table.Cell>
                <Table.Cell title={new Date(trip.estimated_upcoming_stop_arrival_time * 1000).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit'})}>
                  { formatMinutes(estimatedTimeUntilUpcomingStop, true) } { estimatedTimeUntilUpcomingStop > 0 ? 'until' : 'at'}&nbsp;
                  <Link to={`/stations/${trip.upcoming_stop}`}>
                    { formatStation(stations[trip.upcoming_stop].name) }
                  </Link>
                </Table.Cell>
                <Table.Cell>
                  { scheduleDiscrepancy !== null && formatMinutes(scheduleDiscrepancy, false, true) }
                </Table.Cell>
              </Table.Row>
            )
          })
        }
      </Table.Body>
    );
  }

  render() {
    const { open, selectedStation, stations, trains } = this.props;
    const { station, timestamp } = this.state;
    const stationName = formatStation(selectedStation.name);
    const heading = selectedStation.secondary_name ? `${stationName} (${selectedStation.secondary_name})` : stationName;
    const title = `goodservice.io - ${heading} Station`;
    return (
      <Modal basic size='fullscreen' open={open} closeIcon dimmer='blurring'
        onClose={this.handleOnClose} closeOnDocumentClick closeOnDimmerClick className='station-modal'>
        {
          !station &&
          <Dimmer active>
            <Loader inverted></Loader>
          </Dimmer>
        }
        {
          station &&
          <React.Fragment>
            <Helmet>
              <title>{title}</title>
              <meta property="og:title" content={title} />
              <meta name="twitter:title" content={title} />
              <meta property="og:url" content={`https://preview.goodservice.io/stations/${selectedStation.id}`} />
              <meta name="twitter:url" content={`https://preview.goodservice.io/stations/${selectedStation.id}`} />
            </Helmet>
            <Modal.Header>
              <Header as='h3' inverted>
                <Header.Content>
                  { stationName }&nbsp;
                  {
                    accessibilityIcon(selectedStation.accessibility)
                  }
                  <div className="train-list">
                  {
                    Object.keys(selectedStation.routes).map((trainId) => {
                      const train = trains[trainId];
                      return (
                        <TrainBullet link={true} id={train.id} key={train.id} name={train.name} color={train.color} textColor={train.text_color} size='small' directions={selectedStation.routes[trainId]} />
                      );
                    })
                  }
                  </div>
                </Header.Content>
                {
                  selectedStation.secondary_name &&
                  <Header.Subheader>
                    { selectedStation.secondary_name }
                  </Header.Subheader>
                }
              </Header>
            </Modal.Header>
            <Modal.Content scrolling>
              {
                this.renderAccessibilityAdvisories(selectedStation)
              }
              {
                this.renderTransfers(selectedStation, trains, stations)
              }
              {
                this.renderDepartureTable('north', station, trains, stations)
              }
              {
                this.renderDepartureTable('south', station, trains, stations)
              }
              <Modal.Description>
                <Header inverted as='h5'>
                  Last updated {timestamp && (new Date(timestamp * 1000)).toLocaleTimeString('en-US')}.<br />
                </Header>
              </Modal.Description>
            </Modal.Content>
          </React.Fragment>
        }
      </Modal>
    )
  }
}

export default withRouter(StationModal);