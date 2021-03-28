import React from 'react';
import { Modal, Table, Header, Popup, List, Divider } from "semantic-ui-react";
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
    this.state = {};
  }

  componentDidMount() {
    this.fetchData();
    this.timer = setInterval(() => this.fetchData(), 30000);
  }

  componentWillUnmount() {
    clearInterval(this.timer);
  }

  fetchData() {
    const { train, selectedTrip } = this.props;

    fetch(`${API_URL_PREFIX}${train.id}/trips/${selectedTrip.id.replace('..', '-').replace('.', '-')}`)
      .then(response => response.json())
      .then(data => this.setState({ trip: data, timestamp: data.timestamp}))
  }

  handleOnClose = () => {
    const { history, train, direction } = this.props;
    const directionKey = direction[0].toUpperCase();
    clearInterval(this.timer);
    return history.push(`/trains/${train.id}/${directionKey}`);
  };

  renderTableBody() {
    const { train, trains, selectedTrip, routing, stations } = this.props;
    const { trip } = this.state;
    const currentTime = Date.now() / 1000;
    const i = routing.indexOf(selectedTrip.upcoming_stop);
    const j = routing.indexOf(selectedTrip.destination_stop) + 1;
    const remainingStops = routing.slice(i, j);
    let previousStopId = null;
    let currentEstimatedTime = selectedTrip.estimated_upcoming_stop_arrival_time;
    let currentArrivalTime = selectedTrip.upcoming_stop_arrival_time;
    return (
      <Table.Body>
        {
          remainingStops.map((stopId) => {
            if (previousStopId) {
              const estimatedTravelTime = train.estimated_travel_times[`${previousStopId}-${stopId}`] || train.supplemented_travel_times[`${previousStopId}-${stopId}`] || train.scheduled_travel_times[`${previousStopId}-${stopId}`]
              currentEstimatedTime += estimatedTravelTime;
              if (trip) {
                currentArrivalTime = trip.stop_times[stopId];
              }
            }
            let transfers = Object.assign({}, stations[stopId].routes);
            if (stations[stopId]?.transfers) {
              stations[stopId]?.transfers.forEach((s) => {
                transfers = Object.assign(transfers, stations[s].routes);
              });
            }
            delete transfers[train.id];
            const timeUntilEstimatedTime = Math.round((currentEstimatedTime - currentTime) / 60);
            const timeUntilArrivalTime = Math.round((currentArrivalTime - currentTime) / 60);
            const results = (
              <Table.Row key={stopId}>
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
                  { formatMinutes(timeUntilEstimatedTime, true) }
                </Table.Cell>
                <Table.Cell>
                  {new Date(currentEstimatedTime * 1000).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit'})}
                </Table.Cell>
                <Table.Cell>
                  { trip && formatMinutes(timeUntilArrivalTime, true) }
                </Table.Cell>
                <Table.Cell>
                  { trip && new Date(currentArrivalTime * 1000).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit'})}
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
    const { selectedTrip, train, stations } = this.props;
    const { trip } = this.state;
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
          <meta property="og:url" content={`https://preview.goodservice.io/trains/${train.id}`} />
          <meta name="twitter:url" content={`https://preview.goodservice.io/trains/${train.id}`} />
        </Helmet>
        <Modal.Header className='modal-header'>
          <TrainBullet name={train.name} color={train.color}
                        textColor={train.text_color} style={{display: "inline-block", marginLeft: 0}} size='large' /><br />
          Trip: {selectedTrip.id} <br />
          To: { destinationStationName }<br />
          { Math.abs(Math.round(selectedTrip.schedule_discrepancy / 60))} min {Math.round(selectedTrip.schedule_discrepancy / 60) > 0 ? 'behind' : 'ahead of'} schedule
          {
            delayed && 
            <Header as='h5' color='red' inverted>{ delayInfo }</Header>
          }
        </Modal.Header>
        <Modal.Content scrolling>
          <Modal.Description>
            <Divider inverted horizontal>
              <Header size='medium' inverted>
                UPCOMING ARRIVAL TIMES
                <Popup trigger={<sup>[?]</sup>}>
                  <Popup.Header>Upcoming Arrival Times</Popup.Header>
                  <Popup.Content>
                    <List relaxed='very' divided>
                      <List.Item>
                        <List.Header>Projected</List.Header>
                        Time projected until train arrives at the given stop, calculated from train's estimated position and recent trips.
                      </List.Item>
                      <List.Item>
                        <List.Header>Estimated</List.Header>
                        Reported time until train arrives at the given stop from the real-time feeds.
                      </List.Item>
                    </List>
                  </Popup.Content>
                </Popup>
              </Header>
            </Divider>
            <Table fixed inverted unstackable className='trip-table'>
              <Table.Header>
                <Table.Row>
                  <Table.HeaderCell rowSpan={2} width={5}>
                    Station
                  </Table.HeaderCell>
                  <Table.HeaderCell colSpan={2}>
                    Projected
                  </Table.HeaderCell>
                  <Table.HeaderCell colSpan={2}>
                    Estimated
                  </Table.HeaderCell>
                </Table.Row>
                <Table.Row>
                  <Table.HeaderCell width={2}>
                    ETA
                  </Table.HeaderCell>
                  <Table.HeaderCell width={2}>
                    Arrival Time
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
                this.renderTableBody()
              }
            </Table>
            <Header inverted as='h5'>
              Last updated {trip && (new Date(trip.timestamp * 1000)).toLocaleTimeString('en-US')}.<br />
            </Header>
          </Modal.Description>
        </Modal.Content>
      </Modal>
    );
  }
}

export default withRouter(TripModal);