import React from 'react';
import { Header, Segment, Statistic, Grid, Dropdown, Table } from "semantic-ui-react";

import TrainMap from './trainMap';
import { statusColor, formatStation, replaceTrainBulletsInParagraphs } from './utils';

import './trainModalDirectionPane.scss';

class TrainModalDirectionPane extends React.Component {
  constructor(props) {
    super(props);
    this.state = { routings: [], selectedRouting: 'blended' };
  }

  componentDidUpdate(prevProps) {
    const { train, direction } = this.props;
    const { routings, selectedRouting } = this.state;

    if (!train.actual_routings || !train.actual_routings[direction]) {
      return;
    }
    if (prevProps.train === train && prevProps.direction === direction) {
      const prevRoutingHashes = Object.keys(routings);
      const currRoutingHashes = train.actual_routings[direction].map((r) => this.hashRouting(r));
      const isIdentical = prevRoutingHashes.length === currRoutingHashes.length && prevRoutingHashes.every((value, index) => value === currRoutingHashes[index])

      if (!isIdentical) {
        let newSelectedRouting = selectedRouting;
        const newRoutings = {};
        if (newSelectedRouting !== 'blended') {
          newSelectedRouting = currRoutingHashes.includes(newSelectedRouting) ? newSelectedRouting : 'blended';
        }
        train.actual_routings[direction].forEach((r) => {
          routings[this.hashRouting(r)] = r;
        });
        this.setState({ routings: newRoutings, selectedRouting: newSelectedRouting })
      }
    } else {
      const routings = {};
      train.actual_routings[direction].forEach((r) => {
        routings[this.hashRouting(r)] = r;
      });

      this.setState({ routings: routings, selectedRouting: 'blended' })
    }
  }

  componentDidMount() {
    const { train, direction } = this.props;
    const routings = {};
    if (!train.actual_routings || !train.actual_routings[direction]) {
      return;
    }
    train.actual_routings[direction].forEach((r) => {
      routings[this.hashRouting(r)] = r;
    });

    this.setState({ routings: routings, selectedRouting: 'blended' })
  }

  hashRouting(routing) {
    return `${routing[0]}-${routing[routing.length-1]}-${routing.length}`
  }

  directionStatus() {
    const { train, direction } = this.props;
    if (['No Service', 'Not Scheduled'].includes(train.status)) {
      return train.status;
    }
    if (train.direction_statuses && train.direction_statuses[direction]) {
      return train.direction_statuses[direction];
    }
    return 'No Service';
  }

  renderServiceChanges() {
    const { train, trains, direction } = this.props;

    if (!train.service_change_summaries) {
      return;
    }

    const summaries = ['both', direction].map((key) => train.service_change_summaries[key]).flat();
    return replaceTrainBulletsInParagraphs(trains, summaries);
  }

  renderSummary() {
    const { train, direction } = this.props;
    let out = [];
    if (!train.service_summaries) {
      return out;
    }
    if (train.service_summaries[direction]) {
      out.push(<Header as='h4' inverted key='1'>{formatStation(train.service_summaries[direction])}</Header>)
    }
    return out;
  }

  routingOptions() {
    const { train } = this.props;
    const { routings, selectedRouting } = this.state;
    const options = Object.keys(routings).map((hash) => {
      const routing = routings[hash];
      return {
        key: hash,
        text: `${formatStation(train.stops[routing[0]])} ➜ ${formatStation(train.stops[routing[routing.length - 1]])} (${routing.length} stops)`,
        value: hash,
      };
    });
    options.unshift({
      key: 'blended',
      text: "Overall",
      value: 'blended',
    });
    return options;
  }

  handleRoutingChange = (e, { name, value }) => {
    this.setState({ [name]: value });
  };

  renderTripsTableBody() {
    const { train, direction } = this.props;
    const { selectedRouting } = this.state;
    const currentTime = Date.now() / 1000;
    let trips = train.trips[direction][selectedRouting];
    if (!trips) {
      const key = Object.keys(train.trips[direction])[0];
      trips = train.trips[direction][key];
    }
    let scheduledHeadways = train.scheduled_headways[direction] && train.scheduled_headways[direction][selectedRouting];
    if (!scheduledHeadways && train.scheduled_headways[direction]) {
      const key = Object.keys(train.scheduled_headways[direction])[0];
      scheduledHeadways = train.scheduled_headways[direction][key];
    }
    const maxScheduledHeadway = scheduledHeadways ? Math.round(Math.max(...scheduledHeadways) / 60) : Infinity;
    return (
      <Table.Body>
        {
          trips.map((trip) => {
            const delayed = trip.delayed_time > 300;
            const delayInfo = delayed ? `(delayed for ${Math.round(trip.delayed_time / 60)} mins)` : '';
            const estimatedTimeUntilUpcomingStop = Math.round((trip.estimated_upcoming_stop_arrival_time - currentTime) / 60);
            const upcomingStopArrivalTime = Math.round((trip.upcoming_stop_arrival_time - currentTime) / 60);
            const estimatedTimeBehindNextTrain = trip.estimated_time_behind_next_train && Math.round(trip.estimated_time_behind_next_train / 60);
            const timeBehindNextTrain = trip.time_behind_next_train && Math.round(trip.time_behind_next_train / 60);
            return (
              <Table.Row key={trip.id} className={delayed && 'delayed'}>
                <Table.Cell>
                  {trip.id} to {formatStation(train.stops[trip.destination_stop])} {delayInfo && <Header as='h5' inverted color='red'>{delayInfo}</Header> }
                </Table.Cell>
                <Table.Cell title={new Date(trip.estimated_upcoming_stop_arrival_time * 1000).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit'})}>
                  { this.formatMinutes(estimatedTimeUntilUpcomingStop) }
                </Table.Cell>
                <Table.Cell title={new Date(trip.upcoming_stop_arrival_time * 1000).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit'})}>
                  { this.formatMinutes(upcomingStopArrivalTime)}
                </Table.Cell>
                <Table.Cell>
                  { formatStation(train.stops[trip.upcoming_stop]) }
                </Table.Cell>
                <Table.Cell className={estimatedTimeBehindNextTrain > maxScheduledHeadway && 'long-headway'}>
                  { estimatedTimeBehindNextTrain && this.formatMinutes(estimatedTimeBehindNextTrain) }
                </Table.Cell>
                <Table.Cell className={timeBehindNextTrain > maxScheduledHeadway && 'long-headway'}>
                  { timeBehindNextTrain && this.formatMinutes(timeBehindNextTrain) }
                </Table.Cell>
              </Table.Row>
            )
          })
        }
      </Table.Body>
    );
  }

  formatMinutes(minutes) {
    if (minutes > 1) {
      return `${minutes} mins`
    }
    if (minutes > 0) {
      return `${minutes} min`
    }
    return `Due`
  }

  render() {
    const { trains, train, direction } = this.props;
    const { selectedRouting, routings } = this.state;
    const routingToMap = selectedRouting == 'blended' ? train.actual_routings[direction] :[routings[selectedRouting]];
    return (
      <Segment basic className='train-modal-direction-pane'>
        <Grid textAlign='center'>
          <Grid.Row>
            <Grid.Column width={4}>
            {
              train.actual_routings && train.actual_routings[direction] &&

                <TrainMap trains={trains} routings={{ south: routingToMap, north: [] }} color={train.color} stops={train.stops} transfersInfo={train.transfers} />
            }
            </Grid.Column>
            <Grid.Column width={12}>
              <Statistic.Group widths={1} color={ statusColor(this.directionStatus()) } size='small' inverted>
                <Statistic>
                  <Statistic.Value>{ this.directionStatus() }</Statistic.Value>
                  <Statistic.Label>{train.destinations && train.destinations[direction] ? `${formatStation(train.destinations[direction].join('/'))}-bound trains Status` : 'Status' }</Statistic.Label>
                </Statistic>
              </Statistic.Group>
              {
                this.renderServiceChanges()
              }
              {
                this.renderSummary()
              }
              {
                train.actual_routings && train.actual_routings[direction] && train.actual_routings[direction].length > 1 &&
                <Dropdown
                  name='selectedRouting'
                  fluid
                  selection
                  options={this.routingOptions()}
                  onChange={this.handleRoutingChange}
                  value={selectedRouting}
                />
              }
              {
                train.trips && train.trips[direction] && selectedRouting === 'blended' && Object.keys(routings).length > 1 &&
                <Header as='h3' inverted textAlign='left'>Trains on shared section only</Header>
              }
              { train.trips && train.trips[direction] &&
                <Table fixed inverted className='trip-table'>
                  <Table.Header>
                    <Table.Row>
                      <Table.HeaderCell rowSpan='2' width={4}>
                        Train ID / Destination
                      </Table.HeaderCell>
                      <Table.HeaderCell colSpan='3'>
                        Time Until Next Stop
                      </Table.HeaderCell>
                      <Table.HeaderCell colSpan='2'>
                        Time Behind Next Train
                      </Table.HeaderCell>
                    </Table.Row>
                    <Table.Row>
                      <Table.HeaderCell width={2}>
                        Our Estimate
                      </Table.HeaderCell>
                      <Table.HeaderCell width={2}>
                        Official
                      </Table.HeaderCell>
                      <Table.HeaderCell width={3}>
                        Stop Name
                      </Table.HeaderCell>
                      <Table.HeaderCell width={2}>
                        Our Estimate
                      </Table.HeaderCell>
                      <Table.HeaderCell width={2}>
                        Official
                      </Table.HeaderCell>
                    </Table.Row>
                  </Table.Header>
                  {
                    this.renderTripsTableBody()
                  }
                </Table>
              }
            </Grid.Column>
         </Grid.Row>
        </Grid>
      </Segment>
    )
  }
}

export default TrainModalDirectionPane;