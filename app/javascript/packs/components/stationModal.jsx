import React from 'react';
import { Modal, Dimmer, Loader, Header, Table, Statistic, Divider, Segment, List, Popup } from "semantic-ui-react";
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
        <Divider inverted horizontal>
          <Header size='medium' inverted>
            TRANSFERS
          </Header>
        </Divider>
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
              <Table.HeaderCell rowSpan='2' width={5}>
                Train ID / Destination
              </Table.HeaderCell>
              <Table.HeaderCell colSpan='2'>
                Time Until Departure
              </Table.HeaderCell>
              <Table.HeaderCell rowSpan='2' width={4}>
                Current Location
              </Table.HeaderCell>
              <Table.HeaderCell rowSpan='2'>
                Schedule Adherence
              </Table.HeaderCell>
            </Table.Row>
            <Table.Row>
              <Table.HeaderCell>
                Projected
              </Table.HeaderCell>
              <Table.HeaderCell>
                Estimated
              </Table.HeaderCell>
            </Table.Row>
          </Table.Header>
          {
            this.renderDepartureTableBody(trips, trains, stations, currentTime)
          }
        </Table>
      </React.Fragment>
    );
  }

  renderDepartureTableBody(trips, trains, stations, currentTime) {
    return (
      <Table.Body>
        {
          trips.map((trip) => {
            const train = trains[trip.route_id];
            const delayed = trip.delayed_time > 300;
            const effectiveDelayedTime = Math.max(Math.min(trip.schedule_discrepancy, trip.delayed_time), 0);
            const delayedTime = trip.is_delayed ? effectiveDelayedTime : trip.delayed_time;
            const delayInfo = delayed ? `(${trip.is_delayed ? 'delayed' : 'held'} for ${Math.round(delayedTime / 60)} mins)` : '';
            const estimatedTimeUntilUpcomingStop = Math.round((trip.estimated_upcoming_stop_arrival_time - currentTime) / 60);
            const upcomingStopArrivalTime = Math.round((trip.upcoming_stop_arrival_time - currentTime) / 60);
            const estimatedTimeUntilThisStop = Math.round((trip.estimated_current_stop_arrival_time - currentTime) / 60);
            const timeUntilThisStop = Math.round((trip.current_stop_arrival_time - currentTime) / 60);
            const scheduleDiscrepancy = trip.schedule_discrepancy !== null ? Math.round(trip.schedule_discrepancy / 60) : 0;
            let scheduleDiscrepancyClass = 'early';
            if (Math.round(trip.schedule_discrepancy / 60) >= 1) {
              scheduleDiscrepancyClass = 'late';
            }
            return (
              <Table.Row key={trip.id} className={delayed ? 'delayed' : ''}>
                <Table.Cell>
                  <Link to={`/trains/${trip.route_id}/${trip.direction[0].toUpperCase()}/${trip.id}`}>
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
                  <Link to={`/stations/${trip.upcoming_stop}`} className='station-name'>
                    { formatStation(stations[trip.upcoming_stop].name) }
                  </Link>
                </Table.Cell>
                <Table.Cell className={scheduleDiscrepancyClass}>
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
      <Modal basic size='large' open={open} closeIcon dimmer='blurring'
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
              <Divider inverted horizontal>
                <Header size='medium' inverted>
                  UPCOMING DEPARTURE TIMES
                  <Popup trigger={<sup>[?]</sup>}>
                    <Popup.Header>Upcoming Departure Times</Popup.Header>
                    <Popup.Content>
                      <List relaxed='very' divided>
                        <List.Item>
                          <List.Header>Projected Time Until Departure</List.Header>
                          Time projected until train departs given station, calculated from train's estimated position and recent trips.
                        </List.Item>
                        <List.Item>
                          <List.Header>Estimated Time Until Departure</List.Header>
                          Reported time until train departs given station from the real-time feeds.
                        </List.Item>
                        <List.Item>
                          <List.Header>Schedule Adherence</List.Header>
                          Comparison of train's schedule with its current status.
                          Negative value indicates train is ahead of schedule, positive value indicates train is behind schedule.
                        </List.Item>
                      </List>
                    </Popup.Content>
                  </Popup>
                </Header>
              </Divider>
              {
                this.renderDepartureTable('north', station, trains, stations)
              }
              {
                this.renderDepartureTable('south', station, trains, stations)
              }
              <Modal.Description>
                <Header inverted as='h5'>
                  View on a map at <a href={`https://www.theweekendest.com/stations/${station.id}`} target="_blank">The Weekendest</a>.<br />
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