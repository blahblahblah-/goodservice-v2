import React from 'react';
import { Header, Segment, Statistic, Grid, Dropdown, Table, Divider } from "semantic-ui-react";
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
    let travelTimeFrom = null;
    let travelTimeTo = null;

    if (train.actual_routings && train.actual_routings[direction]) {
      const commonStops = train.actual_routings[direction][0].filter((s) => train.actual_routings[direction].every((r) => r.includes(s)));
      travelTimeFrom = commonStops[0];
      travelTimeTo = commonStops[commonStops.length - 1];
    }

    this.setState({ routings: routings, selectedRouting: 'blended', travelTimeFrom: travelTimeFrom, travelTimeTo: travelTimeTo})
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

  calculateMaxHeadway(headwayObjs) {
    const { selectedRouting } = this.state;
    let scheduledHeadways = headwayObjs && headwayObjs[selectedRouting];
    if (selectedRouting === 'blended' && Object.keys(headwayObjs).length > 1) {
      const keys = Object.keys(headwayObjs);
      const headways = keys.map((r) => {
        return r && Math.round(Math.max(...headwayObjs[r]) / 60);
      }).filter((h) => h);
      const minHeadway = Math.min(...headways);
      const maxHeadway = Math.max(...headways);
      if (headways.length > 1 && minHeadway !== maxHeadway) {
        return `${minHeadway}-${maxHeadway}`;
      } else {
        return headways[0];
      }
    }
    if (!scheduledHeadways && headwayObjs) {
      const key = Object.keys(headwayObjs)[0];
      scheduledHeadways = headwayObjs[key];
    }
    return scheduledHeadways ? Math.round(Math.max(...scheduledHeadways) / 60) : "--";
  }

  calculateRoutingRuntime(routing, travelTimes) {
    let time = 0;
    let prev = routing[0];
    for(let i = 1; i < routing.length; i++) {
      time += travelTimes[`${prev}-${routing[i]}`];
      prev = routing[i];
    }
    return Math.round(time / 60);
  }

  calculateRuntime(routings, travelTimes, fromStop, toStop) {
    const { selectedRouting } = this.state;
    if (!routings) {
      return '--';
    }
    if (selectedRouting === 'blended') {
      let selectedRoutings = routings;
      if (fromStop && toStop) {
        selectedRoutings = routings.filter((r) => r.includes(fromStop) && r.includes(toStop)).map((r) => {
          const indexFrom = r.indexOf(fromStop);
          const indexTo = r.indexOf(toStop);
          return r.slice(indexFrom, indexTo + 1);
        });
      }
      const runtimes = selectedRoutings.map((r) => this.calculateRoutingRuntime(r, travelTimes));
      const minRuntime = Math.min(...runtimes);
      const maxRuntime = Math.max(...runtimes);
      if (minRuntime !== maxRuntime) {
        return `${minRuntime}-${maxRuntime}`;
      } else {
        return runtimes[0];
      }
    }
    let routing = routings.find((r) => selectedRouting === `${r[0]}-${r[r.length - 1]}-${r.length}`);
    if (routing) {
      if (fromStop && toStop) {
        const indexFrom = routing.indexOf(fromStop);
        const indexTo = routing.indexOf(toStop);
        routing = routing.slice(indexFrom, indexTo + 1);
      }
      return this.calculateRoutingRuntime(routing, travelTimes);
    }
    return '--';
  }


  renderStats() {
    const { train, direction } = this.props;
    const { selectedRouting } = this.state;
    const maxScheduledHeadway = train.scheduled_headways ? this.calculateMaxHeadway(train.scheduled_headways[direction]) : '--';
    const trips = {}
    if (train.trips && train.trips[direction]) {
      Object.keys(train.trips[direction]).forEach((r) => {
        trips[r] = train.trips[direction][r].map((t) => {
          return t.estimated_time_behind_next_train;
        })
      });
    }
    const maxEstimatedHeadway = this.calculateMaxHeadway(trips);
    const scheduledRuntime = this.calculateRuntime(train.actual_routings && train.actual_routings[direction], train.scheduled_travel_times);
    const supplementaryRuntime = this.calculateRuntime(train.actual_routings && train.actual_routings[direction], train.supplementary_travel_times);
    const estimatedRuntime = this.calculateRuntime(train.actual_routings && train.actual_routings[direction], train.estimated_travel_times);

    let headwayDisrepancyAboveThreshold = false;
    let runtimeDiffAboutThreshold = false;
    if (selectedRouting === 'blended') {
      headwayDisrepancyAboveThreshold = train.max_headway_discrepancy && train.max_headway_discrepancy[direction] && train.max_headway_discrepancy[direction] >= 120;
    } else if (maxEstimatedHeadway && maxScheduledHeadway) {
      headwayDisrepancyAboveThreshold = maxEstimatedHeadway - maxScheduledHeadway >= 2;
    }

    if (selectedRouting === 'blended') {
      runtimeDiffAboutThreshold = train.overall_runtime_diff && train.overall_runtime_diff[direction] && train.overall_runtime_diff[direction] >= 300;
    } else {
      runtimeDiffAboutThreshold = train.runtime_diffs && train.runtime_diffs[direction] && train.runtime_diffs[direction][selectedRouting] && train.runtime_diffs[direction][selectedRouting] >= 300;
    }
    return (
      <React.Fragment>
        <Divider inverted horizontal>
          <Header size='medium' inverted>MAX HEADWAY</Header>
        </Divider>
        <Statistic.Group widths={2} size="small" inverted color={headwayDisrepancyAboveThreshold ? 'yellow' : 'black'}>
          <Statistic>
            <Statistic.Value>{ maxScheduledHeadway } <span className='minute'>min</span></Statistic.Value>
            <Statistic.Label>Scheduled</Statistic.Label>
          </Statistic>
          <Statistic>
            <Statistic.Value>{ maxEstimatedHeadway } <span className='minute'>min</span></Statistic.Value>
            <Statistic.Label>Projected</Statistic.Label>
          </Statistic>
        </Statistic.Group>
        <Divider inverted horizontal>
          <Header size='medium' inverted>TRIP RUNTIMES</Header>
        </Divider>
        <Statistic.Group widths={3} size="small" inverted color={runtimeDiffAboutThreshold ? 'yellow' : 'black'}>
          <Statistic>
            <Statistic.Value>{ scheduledRuntime } <span className='minute'>min</span></Statistic.Value>
            <Statistic.Label>Scheduled</Statistic.Label>
          </Statistic>
          <Statistic>
            <Statistic.Value>{ supplementaryRuntime } <span className='minute'>min</span></Statistic.Value>
            <Statistic.Label>Estimated</Statistic.Label>
          </Statistic>
          <Statistic>
            <Statistic.Value>{ estimatedRuntime } <span className='minute'>min</span></Statistic.Value>
            <Statistic.Label>Projected</Statistic.Label>
          </Statistic>
        </Statistic.Group>
      </React.Fragment>
    );
  }

  travelTimeFrom() {
    const { train, direction } = this.props;
    const { travelTimeTo, selectedRouting } = this.state;

    if (selectedRouting === 'blended') {
      const routings = train.actual_routings[direction].filter((r) => r.includes(travelTimeTo)).map((r) => {
        const i = r.indexOf(travelTimeTo);
        return r.slice(0, i);
      });
      return [...new Set(routings.flat())].map((stopId) => {
        return {
          key: stopId,
          text: formatStation(train.stops[stopId]),
          value: stopId,
        };
      });
    }
    const routing = train.actual_routings[direction].find((r) => selectedRouting === `${r[0]}-${r[r.length - 1]}-${r.length}`);
    const i = routing.indexOf(travelTimeTo);
    return routing.slice(0, i).map((stopId) => {
      return {
        key: stopId,
        text: formatStation(train.stops[stopId]),
        value: stopId,
      };
    });
  }

  travelTimeTo() {
    const { train, direction } = this.props;
    const { travelTimeFrom, selectedRouting } = this.state;

    if (selectedRouting === 'blended') {
      const routings = train.actual_routings[direction].filter((r) => r.includes(travelTimeFrom)).map((r) => {
        const i = r.indexOf(travelTimeFrom);
        return r.slice(i + 1);
      });
      return [...new Set(routings.flat())].map((stopId) => {
        return {
          key: stopId,
          text: formatStation(train.stops[stopId]),
          value: stopId,
        };
      });
    }
    const routing = train.actual_routings[direction].find((r) => selectedRouting === `${r[0]}-${r[r.length - 1]}-${r.length}`);
    const i = routing.indexOf(travelTimeFrom);
    return routing.slice(i + 1).map((stopId) => {
      return {
        key: stopId,
        text: formatStation(train.stops[stopId]),
        value: stopId,
      };
    });
  }

  renderTravelTime() {
    const { train, direction } = this.props;
    const { travelTimeFrom, travelTimeTo } = this.state;
    const scheduledRuntime = this.calculateRuntime(train.actual_routings && train.actual_routings[direction], train.scheduled_travel_times, travelTimeFrom, travelTimeTo);
    const supplementaryRuntime = this.calculateRuntime(train.actual_routings && train.actual_routings[direction], train.supplementary_travel_times, travelTimeFrom, travelTimeTo);
    const estimatedRuntime = this.calculateRuntime(train.actual_routings && train.actual_routings[direction], train.estimated_travel_times, travelTimeFrom, travelTimeTo);
    return (
      <React.Fragment>
        <Divider inverted horizontal>
          <Header size='medium' inverted>TRAVEL TIME</Header>
        </Divider>
        <Header as='h3' inverted className='travel-time-header'>
          <Dropdown
            name='travelTimeFrom'
            floating
            inline
            scrolling
            options={this.travelTimeFrom()}
            onChange={this.handleOptionChange}
            value={travelTimeFrom}
          />
            to
          <Dropdown
            name='travelTimeTo'
            floating
            inline
            scrolling
            options={this.travelTimeTo()}
            onChange={this.handleOptionChange}
            value={travelTimeTo}
          />
        </Header>
        <Statistic.Group widths={3} size="small" inverted>
          <Statistic>
            <Statistic.Value>{ scheduledRuntime } <span className='minute'>min</span></Statistic.Value>
            <Statistic.Label>Scheduled</Statistic.Label>
          </Statistic>
          <Statistic>
            <Statistic.Value>{ supplementaryRuntime } <span className='minute'>min</span></Statistic.Value>
            <Statistic.Label>Estimated</Statistic.Label>
          </Statistic>
          <Statistic>
            <Statistic.Value>{ estimatedRuntime } <span className='minute'>min</span></Statistic.Value>
            <Statistic.Label>Projected</Statistic.Label>
          </Statistic>
        </Statistic.Group>
      </React.Fragment>
    );
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

  handleOptionChange = (e, { name, value }) => {
    const { train, direction } = this.props;
    const { selectedRouting } = this.state;
    const newState = { [name]: value };
    if (name === 'selectedRouting' && value !== 'blended') {
      const routing = train.actual_routings[direction].find((r) => value === `${r[0]}-${r[r.length - 1]}-${r.length}`);
      newState['travelTimeFrom'] = routing[0];
      newState['travelTimeTo'] = routing[routing.length - 1];
    }
    this.setState(newState);
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
              Projected
            </Table.HeaderCell>
            <Table.HeaderCell width={2}>
              Estimated
            </Table.HeaderCell>
            <Table.HeaderCell width={3}>
              Stop Name
            </Table.HeaderCell>
            <Table.HeaderCell width={2}>
              Projected
            </Table.HeaderCell>
            <Table.HeaderCell width={2}>
              Estimated
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
    const { selectedRouting, routings, travelTimeFrom, travelTimeTo } = this.state;
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
                  onChange={this.handleOptionChange}
                  value={selectedRouting}
                />
              }
              {
                this.renderStats()
              }
              {
                train.actual_routings && train.actual_routings[direction] && travelTimeFrom && travelTimeTo && this.renderTravelTime()
              }
              <Divider inverted horizontal>
                <Header size='medium' inverted>ACTIVE TRIPS</Header>
              </Divider>
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