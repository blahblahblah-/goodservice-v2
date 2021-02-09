import React from 'react';
import { Header, Segment, Statistic, Grid, Dropdown, Table } from "semantic-ui-react";
import { Link } from 'react-router-dom';

import TrainMap from './trainMap';
import { statusColor, formatStation, formatMinutes, replaceTrainBulletsInParagraphs, routingHash } from './utils';

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
    if (prevProps.train === train) {
      const prevRoutingHashes = Object.keys(routings);
      const currRoutingHashes = train.actual_routings[direction].map((r) => routingHash(r));
      const isIdentical = prevRoutingHashes.length === currRoutingHashes.length && prevRoutingHashes.every((value, index) => value === currRoutingHashes[index])

      if (!isIdentical) {
        let newRoutings = {};
        let newSelectedRouting = selectedRouting;

        train.actual_routings[direction].forEach((r) => {
          newRoutings[routingHash(r)] = r;
        });

        if (newSelectedRouting !== 'blended') {
          newSelectedRouting = currRoutingHashes.includes(newSelectedRouting) ? newSelectedRouting : 'blended';
        }

        this.setState({ routings: newRoutings, selectedRouting: newSelectedRouting })
      }
    }
  }

  componentDidMount() {
    const { train, direction } = this.props;
    const routings = {};
    if (!train.actual_routings || !train.actual_routings[direction]) {
      return;
    }
    train.actual_routings[direction].forEach((r) => {
      routings[routingHash(r)] = r;
    });

    this.setState({ routings: routings, selectedRouting: 'blended' })
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

  renderTripsTableBody(selectedRouting, trips) {
    const { train, direction, match } = this.props;
    const currentTime = Date.now() / 1000;
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
            const effectiveDelayedTime = Math.max(trip.schedule_discrepancy, 0) + trip.delayed_time;
            const delayedTime = trip.is_delayed ? effectiveDelayedTime : trip.delayed_time;
            const delayInfo = delayed ? `(${trip.is_delayed ? 'delayed' : 'held'} for ${Math.round(delayedTime / 60)} mins)` : '';
            const estimatedTimeUntilUpcomingStop = Math.round((trip.estimated_upcoming_stop_arrival_time - currentTime) / 60);
            const upcomingStopArrivalTime = Math.round((trip.upcoming_stop_arrival_time - currentTime) / 60);
            const estimatedTimeBehindNextTrain = trip.estimated_time_behind_next_train !== null ? Math.round(trip.estimated_time_behind_next_train / 60) : null;
            const timeBehindNextTrain = trip.time_behind_next_train !== null ? Math.round(trip.time_behind_next_train / 60): null;
            const scheduleDiscrepancy = trip.schedule_discrepancy !== null ? Math.round(trip.schedule_discrepancy / 60) : 0;
            return (
              <Table.Row key={trip.id} className={delayed ? 'delayed' : ''}>
                <Table.Cell>
                  <Link to={`/trains/${train.id}/${trip.id}`}>
                    {trip.id} to {formatStation(train.stops[trip.destination_stop])} {delayInfo && <Header as='h5' inverted color='red'>{delayInfo}</Header> }
                  </Link>
                </Table.Cell>
                <Table.Cell title={new Date(trip.estimated_upcoming_stop_arrival_time * 1000).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit'})}>
                  { formatMinutes(estimatedTimeUntilUpcomingStop, true) }
                </Table.Cell>
                <Table.Cell title={new Date(trip.upcoming_stop_arrival_time * 1000).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit'})}>
                  { formatMinutes(upcomingStopArrivalTime, true)}
                </Table.Cell>
                <Table.Cell>
                  { formatStation(train.stops[trip.upcoming_stop]) }
                </Table.Cell>
                <Table.Cell className={estimatedTimeBehindNextTrain > maxScheduledHeadway ? 'long-headway' : ''}>
                  { estimatedTimeBehindNextTrain !== null && formatMinutes(estimatedTimeBehindNextTrain, false) }
                </Table.Cell>
                <Table.Cell className={timeBehindNextTrain > maxScheduledHeadway ? 'long-headway' : ''}>
                  { timeBehindNextTrain !== null && formatMinutes(timeBehindNextTrain, false) }
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

  renderBlendedTripsTables(train, direction) {
    const commonRouting = train.common_routings[direction];
    const commonRoutingTrips = train.trips[direction].blended || [];

    const routesBefore = Object.keys(train.trips[direction]).filter((key) => {
      if (key === 'blended') {
        return false;
      }
      const a = key.split('-');
      const trips = train.trips[direction][key];
      return !commonRouting || !commonRouting.includes(a[0]);
    });

    const routesAfter = Object.keys(train.trips[direction]).filter((key) => {
      if (key === 'blended') {
        return false;
      }
      const a = key.split('-');
      const trips = train.trips[direction][key];
      return commonRouting && !commonRouting.includes(a[1]);
    });

    const componentArray = [];

    routesBefore.forEach((key) => {
      if (!commonRouting) {
        const a = key.split('-');
        const start  = a[0];
        const end = a[1];
        const selectedTrips = train.trips[direction][key];
        componentArray.push(this.renderHeadingWithTable(key, selectedTrips, start, end));
      } else {
        const routing = train.actual_routings[direction].find((r) => key === `${r[0]}-${r[r.length - 1]}-${r.length}`);
        const i = routing.indexOf(commonRouting[0]);
        const subrouting = routing.slice(0, i);
        const selectedTrips = train.trips[direction][key].filter((t) => subrouting.includes(t.upcoming_stop));
        componentArray.push(this.renderHeadingWithTable(key, selectedTrips, subrouting[0], commonRouting[0]));
      }
    });

    if (commonRoutingTrips.length > 0) {
      componentArray.push(this.renderHeadingWithTable('blended', commonRoutingTrips, commonRouting[0], commonRouting[commonRouting.length - 1]));
    }

    routesAfter.forEach((key) => {
      const routing = train.actual_routings[direction].find((r) => key === `${r[0]}-${r[r.length - 1]}-${r.length}`);
      const i = routing.indexOf(commonRouting[commonRouting.length - 1]);
      const subrouting = routing.slice(i + 1);
      const selectedTrips = train.trips[direction][key].filter((t) => subrouting.includes(t.upcoming_stop));
      componentArray.push(this.renderHeadingWithTable(key, selectedTrips, commonRouting[commonRouting.length - 1], subrouting[subrouting.length - 1]));
    });

    return (
      <div>
        {
          componentArray
        }
      </div>
    );
  }

  renderHeadingWithTable(selectedRouting, trips, start, end) {
    const { train, direction } = this.props;
    const startName = formatStation(train.stops[start]);
    const endName = formatStation(train.stops[end]);

    return (
      <div key={`${start}-${end}`} className='table-with-heading'>
        <Header as='h3' inverted textAlign='left'>{startName} ➜ {endName}</Header>
        { this.renderTable(selectedRouting, trips) }
      </div>
    );
  }

  renderSingleTable(train, direction) {
    const { selectedRouting } = this.state;

    let trips = train.trips[direction][selectedRouting];
    let routing = selectedRouting;

    if (!trips) {
      const key = Object.keys(train.trips[direction])[0];
      trips = train.trips[direction][key];

      if (selectedRouting === 'blended') {
        routing = key;
      }
    }

    return this.renderTable(routing, trips);
  }

  renderTable(selectedRouting, trips) {
    return (
      <Table fixed inverted unstackable size='small' compact className='trip-table'>
        <Table.Header>
          <Table.Row>
            <Table.HeaderCell rowSpan='2' width={3}>
              Train ID / Destination
            </Table.HeaderCell>
            <Table.HeaderCell colSpan='3'>
              Time Until Next Stop
            </Table.HeaderCell>
            <Table.HeaderCell colSpan='2'>
              Time Behind Next Train
            </Table.HeaderCell>
            <Table.HeaderCell rowSpan='2'>
              Schedule Discrepancy
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
          this.renderTripsTableBody(selectedRouting, trips)
        }
      </Table>
    );
  }

  render() {
    const { trains, train, direction } = this.props;
    const { selectedRouting, routings } = this.state;
    const routingToMap = selectedRouting == 'blended' ? train.actual_routings && train.actual_routings[direction] : [routings[selectedRouting]];
    return (
      <Segment basic className='train-modal-direction-pane'>

        <Grid textAlign='center' stackable>
          <Grid.Row>
            <Grid.Column width={4} className='map-cell'>
            {
              train.actual_routings && train.actual_routings[direction] &&
                <TrainMap trains={trains} train={train} routings={{ south: routingToMap, north: [] }} showTravelTime trips={selectedRouting === 'blended' ? Object.keys(train.trips[direction]).map((key) => train.trips[direction][key]).flat() : train.trips[direction][selectedRouting]} />
            }
            </Grid.Column>
            <Grid.Column width={12} className='trip-table-cell'>
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
                this.renderBlendedTripsTables(train, direction)
              }
              { train.trips && train.trips[direction] && (Object.keys(routings).length === 1 || selectedRouting !== 'blended') &&
                this.renderSingleTable(train, direction)
              }
            </Grid.Column>
            <Grid.Column width={4} className='mobile-map-cell'>
            {
              train.actual_routings && train.actual_routings[direction] &&
                <TrainMap trains={trains} train={train} routings={{ south: routingToMap, north: [] }} showTravelTime trips={selectedRouting === 'blended' ? Object.keys(train.trips[direction]).map((key) => train.trips[direction][key]).flat() : train.trips[direction][selectedRouting]} />
            }
            </Grid.Column>
         </Grid.Row>
        </Grid>
      </Segment>
    )
  }
}

export default TrainModalDirectionPane;