import React from 'react';
import { Modal, Table, Header } from "semantic-ui-react";
import { withRouter } from 'react-router-dom';
import { Helmet } from "react-helmet";

import TrainBullet from './trainBullet';
import { formatStation, formatMinutes } from './utils';

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

  fetchData() {
    const { train, selectedTrip } = this.props;

    fetch(`${API_URL_PREFIX}${train.id}/trips/${selectedTrip.id.replace('..', '-')}`)
      .then(response => response.json())
      .then(data => this.setState({ trip: data, timestamp: data.timestamp}))
  }

  handleOnClose = () => {
    const { history, train } = this.props;
    clearInterval(this.timer);
    return history.push(`/trains/${train.id}`);
  };

  renderTableBody() {
    const { train, selectedTrip, routing } = this.props;
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
              currentEstimatedTime += train.estimated_travel_times[`${previousStopId}-${stopId}`];
              if (trip) {
                currentArrivalTime = trip.stop_times[stopId];
              }
            }
            const timeUntilEstimatedTime = Math.round((currentEstimatedTime - currentTime) / 60);
            const timeUntilArrivalTime = Math.round((currentArrivalTime - currentTime) / 60);
            const results = (
              <Table.Row key={stopId}>
                <Table.Cell>
                  { formatStation(train.stops[stopId]) }
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
    const { selectedTrip, train } = this.props;
    const destinationStationName = formatStation(train.stops[selectedTrip.destination_stop]);
    const title = `goodservice.io - ${train.alternate_name ? `S - ${train.alternate_name}` : train.name} Train - Trip ${selectedTrip.id} to ${destinationStationName}`;
    const delayed = selectedTrip.delayed_time > 300;
    const effectiveDelayedTime = Math.min(selectedTrip.schedule_discrepancy, 0) + selectedTrip.delayed_time;
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
        <Modal.Header>
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
            <Table fixed inverted unstackable className='trip-table'>
              <Table.Header>
                <Table.Row>
                  <Table.HeaderCell rowSpan={2} width={4}>
                    Station
                  </Table.HeaderCell>
                  <Table.HeaderCell colSpan={2}>
                    Our Estimate
                  </Table.HeaderCell>
                  <Table.HeaderCell colSpan={2}>
                    Official
                  </Table.HeaderCell>
                </Table.Row>
                <Table.Row>
                  <Table.HeaderCell width={3}>
                    ETA
                  </Table.HeaderCell>
                  <Table.HeaderCell width={3}>
                    Arrival Time
                  </Table.HeaderCell>
                  <Table.HeaderCell width={3}>
                    ETA
                  </Table.HeaderCell>
                  <Table.HeaderCell width={3}>
                    Arrival Time
                  </Table.HeaderCell>
                </Table.Row>
              </Table.Header>
              {
                this.renderTableBody()
              }
            </Table>
          </Modal.Description>
        </Modal.Content>
      </Modal>
    );
  }
}

export default withRouter(TripModal);