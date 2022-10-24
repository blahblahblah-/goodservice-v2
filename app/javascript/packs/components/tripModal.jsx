import React from 'react';
import { Modal, Table, Header, Divider, Checkbox } from "semantic-ui-react";
import { withRouter, Link } from 'react-router-dom';
import { Helmet } from "react-helmet";

import TrainBullet from './trainBullet';
import { formatStation, formatMinutes } from './utils';
import { accessibilityIcon } from './accessibility.jsx';

import './tripModal.scss';

const API_URL_PREFIX = '/api/routes/';

class TripModal extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      showPastStops: false,
    };
  }

  componentDidMount() {
    this.fetchData();
    this.timer = setInterval(() => this.fetchData(), 15000);
  }

  componentWillUnmount() {
    clearInterval(this.timer);
  }

  fetchData() {
    const { train, selectedTrip } = this.props;

    fetch(`${API_URL_PREFIX}${train.id}/trips/${selectedTrip.id.replace('..', '-').replace('.', '-')}`)
      .then(response => response.json())
      .then(data => this.setState({ trip: data, timestamp: data.timestamp, lastFetched: Date.now() / 1000}))
  }

  handleOnClose = () => {
    const { history, train, direction } = this.props;
    const directionKey = direction[0].toUpperCase();
    clearInterval(this.timer);
    return history.push(`/trains/${train.id}/${directionKey}`);
  };

  handleToggleChange = (e, {checked}) => {
    this.setState({showPastStops: checked});
  }

  renderTableBody(delayed) {
    const { train, trains, selectedTrip, routing, stations } = this.props;
    const { trip, showPastStops, lastFetched } = this.state;
    const currentTime = Date.now() / 1000;
    const i = routing.indexOf(selectedTrip.upcoming_stop);
    const j = routing.indexOf(selectedTrip.destination_stop) + 1;
    const remainingStops = routing.slice(i, j);
    let previousStopId = null;
    let currentEstimatedTime = selectedTrip.estimated_upcoming_stop_arrival_time;
    if (currentEstimatedTime < lastFetched) {
      currentEstimatedTime = lastFetched;
    }
    return (
      <Table.Body>
        {
          showPastStops && trip && Object.keys(trip.past_stops).sort((a, b) => {
            return trip.past_stops[a] - trip.past_stops[b];
          }).map((stopId) => {
            let transfers = Object.assign({}, stations[stopId].routes);
            if (stations[stopId]?.transfers) {
              stations[stopId]?.transfers.forEach((s) => {
                transfers = Object.assign(transfers, stations[s].routes);
              });
            }
            delete transfers[train.id];
            const pastStopTime = trip.past_stops[stopId];
            const timeAfterStopTime = Math.round((pastStopTime - currentTime) / 60);
            return (
              <Table.Row key={stopId}>
                <Table.Cell>
                  <Link to={`/stations/${stopId}`}>
                    <i>{ formatStation(stations[stopId].name) }</i>
                    { accessibilityIcon(stations[stopId].accessibility) }
                    {
                      Object.keys(transfers).sort().map((routeId) => {
                        const directions = transfers[routeId];
                        const train = trains[routeId];
                        return (
                          <TrainBullet id={routeId} key={train.name} name={train.name} color={train.color}
                            textColor={train.text_color} size='small' directions={directions} />
                        )
                      })
                    }
                  </Link>
                </Table.Cell>
                <Table.Cell className='past'>
                  <i>{ formatMinutes(timeAfterStopTime, false) }</i>
                </Table.Cell>
                <Table.Cell className='past'>
                  <i>{new Date(pastStopTime * 1000).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit'})}</i>
                </Table.Cell>
              </Table.Row>
            );
          })
        }
        {
          remainingStops.map((stopId) => {
            if (previousStopId) {
              const estimatedTravelTime = train.estimated_travel_times[`${previousStopId}-${stopId}`] || train.supplemented_travel_times[`${previousStopId}-${stopId}`] || train.scheduled_travel_times[`${previousStopId}-${stopId}`]
              currentEstimatedTime += estimatedTravelTime;
            }
            let transfers = Object.assign({}, stations[stopId].routes);
            if (stations[stopId]?.transfers) {
              stations[stopId]?.transfers.forEach((s) => {
                transfers = Object.assign(transfers, stations[s].routes);
              });
            }
            delete transfers[train.id];
            const timeUntilEstimatedTime = Math.round((currentEstimatedTime - currentTime) / 60);
            const results = (
              <Table.Row key={stopId} className={delayed ? 'delayed' : ''}>
                <Table.Cell>
                  <Link to={`/stations/${stopId}`}>
                    { formatStation(stations[stopId].name) }
                    { accessibilityIcon(stations[stopId].accessibility) }
                    {
                      Object.keys(transfers).sort().map((routeId) => {
                        const directions = transfers[routeId];
                        const train = trains[routeId];
                        return (
                          <TrainBullet id={routeId} key={train.name} name={train.name} color={train.color}
                            textColor={train.text_color} size='small' directions={directions} />
                        )
                      })
                    }
                  </Link>
                </Table.Cell>
                <Table.Cell>
                  { delayed ? '? ? ?' : formatMinutes(timeUntilEstimatedTime, true) }
                </Table.Cell>
                <Table.Cell>
                  { delayed ? '? ? ?' : new Date(currentEstimatedTime * 1000).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit'}) }
                </Table.Cell>
              </Table.Row>
            );
            previousStopId = stopId;
            return results;
          })
        }
      </Table.Body>
    );
  }

  render() {
    const { selectedTrip, train, stations, direction } = this.props;
    const { trip, showPastStops } = this.state;
    const directionKey = direction[0].toUpperCase();
    const destinationStationName = formatStation(stations[selectedTrip.destination_stop].name);
    const title = `goodservice.io - ${train.alternate_name ? `S - ${train.alternate_name}` : train.name} Train - Trip ${selectedTrip.id} to ${destinationStationName}`;
    const delayed = selectedTrip.delayed_time > 300;
    const effectiveDelayedTime = Math.max(Math.min(selectedTrip.schedule_discrepancy, selectedTrip.delayed_time), 0);
    const delayedTime = selectedTrip.is_delayed ? effectiveDelayedTime : selectedTrip.delayed_time;
    const delayInfo = delayed ? `${selectedTrip.is_delayed ? 'Delayed' : 'Held'} for ${Math.round(delayedTime / 60)} mins` : '';
    return (
      <Modal basic size='large' className='trip-modal' open={!!selectedTrip} closeIcon dimmer='blurring' onClose={this.handleOnClose} closeOnDocumentClick closeOnDimmerClick>
        <Helmet>
          <title>{title}</title>
          <meta property="og:title" content={title} />
          <meta name="twitter:title" content={title} />
          <meta property="og:url" content={`https://www.goodservice.io/trains/${train.id}/${directionKey}/${selectedTrip.id}`} />
          <meta name="twitter:url" content={`https://www.goodservice.io/trains/${train.id}/${directionKey}/${selectedTrip.id}`} />
        </Helmet>
        <Modal.Header className='modal-header'>
          <TrainBullet name={train.name} color={train.color}
                        textColor={train.text_color} style={{display: "inline-block", marginLeft: 0}} size='large' />
          <div className='trip-header-info'>
            Trip: {selectedTrip.id} <br />
            To: { destinationStationName }<br />
            { !selectedTrip.is_assigned &&
              <>Train not yet assigned to trip<br/></>
            }
            { Math.abs(Math.round(selectedTrip.schedule_discrepancy / 60))} min {Math.round(selectedTrip.schedule_discrepancy / 60) > 0 ? 'behind' : 'ahead of'} schedule
            {
              delayed &&
              <Header className='delayed-header' as='h3' color='red' inverted>{ delayInfo }</Header>
            }
          </div>
          <Checkbox checked={showPastStops} onChange={this.handleToggleChange} className='past-stops-toggle' toggle label={<label className="toggle-label">Show Past Stops</label>} />
        </Modal.Header>
        <Modal.Content scrolling>
          <Modal.Description>
            <Divider inverted horizontal>
              <Header size='medium' inverted>
                UPCOMING ARRIVAL TIMES
              </Header>
            </Divider>
            <Table fixed inverted unstackable className='trip-table'>
              <Table.Header>
                <Table.Row>
                  <Table.HeaderCell rowSpan={2} width={5}>
                    Station
                  </Table.HeaderCell>
                  <Table.HeaderCell width={2}>
                    ETA
                  </Table.HeaderCell>
                  <Table.HeaderCell width={2}>
                    Arrival Time
                  </Table.HeaderCell>
                </Table.Row>
              </Table.Header>
              {
                this.renderTableBody(delayed)
              }
            </Table>
            <Header inverted as='h5'>
              View on a map at <a href={`https://www.theweekendest.com/trains/${train.id}/${selectedTrip.id}`} target="_blank">The Weekendest</a>.<br />
              Last updated {trip && (new Date(trip.timestamp * 1000)).toLocaleTimeString('en-US')}.<br />
            </Header>
          </Modal.Description>
        </Modal.Content>
      </Modal>
    );
  }
}

export default withRouter(TripModal);