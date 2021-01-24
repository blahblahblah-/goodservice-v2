import React from 'react';
import { Modal, Table, Header } from "semantic-ui-react";
import { withRouter } from 'react-router-dom';

import TrainBullet from './trainBullet';
import { formatStation, formatMinutes } from './utils';

class TripModal extends React.Component {
  handleOnClose = () => {
    const { history, train } = this.props;
    return history.push(`/trains/${train.id}`);
  };

  renderTableBody() {
    const { train, selectedTrip, routing } = this.props;
    const currentTime = Date.now() / 1000;
    const i = routing.indexOf(selectedTrip.upcoming_stop);
    const remainingStops = routing.slice(i);
    let previousStopId = null;
    let currentEstimatedTime = selectedTrip.estimated_upcoming_stop_arrival_time;
    let currentArrivalTime = selectedTrip.upcoming_stop_arrival_time;
    return (
      <Table.Body>
        {
          remainingStops.map((stopId) => {
            if (previousStopId) {
              currentEstimatedTime += train.estimated_travel_times[`${previousStopId}-${stopId}`];
              currentArrivalTime += train.supplementary_travel_times[`${previousStopId}-${stopId}`];
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
                  { formatMinutes(timeUntilArrivalTime, true) }
                </Table.Cell>
                <Table.Cell>
                  {new Date(currentArrivalTime * 1000).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit'})}
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
    return (
      <Modal basic size='large' open={selectedTrip} closeIcon dimmer='blurring' onClose={this.handleOnClose} closeOnDocumentClick closeOnDimmerClick>
        <Modal.Header>
          <TrainBullet name={train.name} color={train.color}
                        textColor={train.text_color} style={{display: "inline-block"}} size='large' /><br />
          Trip: {selectedTrip.id} <br />
          To: { formatStation(train.stops[selectedTrip.destination_stop]) }
          {
            selectedTrip.delayed_time >= 300 && 
            <Header as='h5' color='red' inverted>Delayed for {Math.round(selectedTrip.delayed_time / 60)} mins</Header>
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