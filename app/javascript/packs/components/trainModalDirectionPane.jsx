import React from 'react';
import { Header, Segment, Statistic, Grid, Dropdown, Table, Divider, Popup, List, Label, Checkbox } from "semantic-ui-react";
import { Link } from 'react-router-dom';

import TrainMap from './trainMap';
import TrainBullet from './trainBullet';
import { statusColor, formatStation, formatMinutes, replaceTrainBulletsInParagraphs, routingHash, twitterLink } from './utils';

import './trainModalDirectionPane.scss';

const API_URL_PREFIX = '/api/routes/';

class TrainModalDirectionPane extends React.Component {
  constructor(props) {
    super(props);
    this.state = { routings: [], selectedRouting: 'blended', displayAdditionalTrips: true };
  }

  componentDidUpdate(prevProps) {
    const { train, direction } = this.props;
    const { routings, selectedRouting, travelTimeFrom, travelTimeTo } = this.state;

    if (!train.actual_routings || !train.actual_routings[direction]) {
      return;
    }

    const prevRoutingHashes = Object.keys(routings);
    const currRoutingHashes = train.actual_routings[direction].map((r) => routingHash(r));
    const isIdentical = prevRoutingHashes.length === currRoutingHashes.length && prevRoutingHashes.every((value, index) => value === currRoutingHashes[index])

    if (!isIdentical) {
      let newRoutings = {};
      let newSelectedRouting = selectedRouting;
      let newState = {};

      train.actual_routings[direction].forEach((r) => {
        newRoutings[routingHash(r)] = r;
      });

      if (newSelectedRouting !== 'blended') {
        newSelectedRouting = currRoutingHashes.includes(newSelectedRouting) ? newSelectedRouting : 'blended';
      }

      if (train.actual_routings && train.actual_routings[direction]) {
        const commonStops = train.actual_routings[direction][0].filter((s) => train.actual_routings[direction].every((r) => r.includes(s)));

        if (!train.actual_routings[direction].some((r) => r.includes(travelTimeFrom))) {
          newState['travelTimeFrom'] = commonStops[0];
        }

        if (!train.actual_routings[direction].some((r) => r.includes(travelTimeTo))) {
          newState['travelTimeTo'] = commonStops[commonStops.length - 1];
        }
      }

      newState['routings'] = newRoutings;
      newState['selectedRouting'] = newSelectedRouting;

      this.setState(newState);
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

  componentWillUnmount() {
    clearInterval(this.timer);
  }

  directionStatus() {
    const { train, direction } = this.props;
    if (['No Service', 'Not Scheduled', 'No Data'].includes(train.status)) {
      return train.status;
    }
    if (train.direction_statuses && train.direction_statuses[direction]) {
      return train.direction_statuses[direction];
    }
    return 'No Service';
  }

  renderDelays() {
    const { train, direction } = this.props;
    let out = [];
    if (!train.delay_summaries) {
      return out;
    }
    if (train.delay_summaries[direction]) {
      out.push(<Header as='h4' inverted key='1'>{formatStation(train.delay_summaries[direction])}</Header>)
    }
    if (out.length) {
      return (
        <Segment inverted basic>
          <Label attached='top' color='red'>DELAYS</Label>
          {
            out
          }
        </Segment>
      );
    }
  }


  renderServiceChanges() {
    const { train, trains, direction } = this.props;

    if (!train.service_change_summaries) {
      return;
    }

    const summaries = ['both', direction].map((key) => train.service_change_summaries[key]).flat().filter(n => n);
    if (summaries.length) {
      return (
        <Segment inverted basic>
          <Label attached='top' color='orange'>SERVICE CHANGES</Label>
          {
            replaceTrainBulletsInParagraphs(trains, summaries)
          }
        </Segment>
      );
    }
  }

  renderServiceIrregularities() {
    const { train, direction } = this.props;
    let out = [];
    if (!train.service_irregularity_summaries) {
      return out;
    }
    if (train.service_irregularity_summaries[direction]) {
      out.push(<Header as='h4' inverted key='1'>{formatStation(train.service_irregularity_summaries[direction])}</Header>)
    }
    if (out.length) {
      return (
        <Segment inverted basic>
          <Label attached='top' color='yellow'>SERVICE IRREGULARITIES</Label>
          {
            out
          }
        </Segment>
      );
    }
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
    return scheduledHeadways && scheduledHeadways.filter((h) => h).length > 0 ? Math.max(Math.round(Math.max(...scheduledHeadways) / 60), 0) : "--";
  }

  calculateRoutingRuntime(routing, travelTimes) {
    let time = 0;
    let prev = routing[0];
    for(let i = 1; i < routing.length; i++) {
      time += travelTimes[`${prev}-${routing[i]}`] || 0;
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
    const maxScheduledHeadway = train.scheduled_headways && train.scheduled_headways[direction] ? this.calculateMaxHeadway(train.scheduled_headways[direction]) : '--';
    const trips = {}
    if (train.trips && train.trips[direction]) {
      Object.keys(train.trips[direction]).forEach((r) => {
        trips[r] = train.trips[direction][r].map((t) => {
          return t.estimated_time_behind_next_train || t.estimated_time_until_destination;
        })
      });
    }
    const maxEstimatedHeadway = this.calculateMaxHeadway(trips);
    const scheduledRuntime = this.calculateRuntime(train.actual_routings && train.actual_routings[direction], train.scheduled_travel_times);
    const supplementedRuntime = this.calculateRuntime(train.actual_routings && train.actual_routings[direction], train.supplemented_travel_times);
    const estimatedRuntime = this.calculateRuntime(train.actual_routings && train.actual_routings[direction], train.estimated_travel_times);

    let headwayDisrepancyAboveThreshold = false;
    let runtimeDiffAboutThreshold = false;
    if (selectedRouting === 'blended') {
      headwayDisrepancyAboveThreshold = train.max_headway_discrepancy && train.max_headway_discrepancy[direction] && train.max_headway_discrepancy[direction] >= 120;
    } else if (maxEstimatedHeadway && maxScheduledHeadway) {
      headwayDisrepancyAboveThreshold = maxEstimatedHeadway - maxScheduledHeadway > 2;
    }

    if (selectedRouting === 'blended') {
      runtimeDiffAboutThreshold = train.overall_runtime_diff && train.overall_runtime_diff[direction] && train.overall_runtime_diff[direction] >= 300;
    } else {
      runtimeDiffAboutThreshold = train.runtime_diffs && train.runtime_diffs[direction] && train.runtime_diffs[direction][selectedRouting] && train.runtime_diffs[direction][selectedRouting] >= 300;
    }
    return (
      <React.Fragment>
        <Divider inverted horizontal>
          <Header size='medium' inverted>
            MAX HEADWAY
            <Popup trigger={<sup>[?]</sup>}>
              <Popup.Header>Maximum Headway</Popup.Header>
              <Popup.Content>
                <List relaxed='very' divided>
                  <List.Item>
                    <List.Header>Regularly Scheduled</List.Header>
                    Maximum time between scheduled trains if trains ran on a typical schedule for the current time period.
                  </List.Item>
                  <List.Item>
                    <List.Header>Now</List.Header>
                    Estimated maximum time between trains that are currently running.
                  </List.Item>
                </List>
              </Popup.Content>
            </Popup>
          </Header>
        </Divider>
        <Statistic.Group widths={2} size="small" inverted color={headwayDisrepancyAboveThreshold ? 'yellow' : 'black'}>
          <Statistic>
            <Statistic.Value>{ maxScheduledHeadway } <span className='minute'>min</span></Statistic.Value>
            <Statistic.Label>Reg. Sched.</Statistic.Label>
          </Statistic>
          <Statistic>
            <Statistic.Value>{ maxEstimatedHeadway } <span className='minute'>min</span></Statistic.Value>
            <Statistic.Label>Now</Statistic.Label>
          </Statistic>
        </Statistic.Group>
        <Divider inverted horizontal>
          <Header size='medium' inverted>
            TRIP RUNTIMES
            <Popup trigger={<sup>[?]</sup>}>
              <Popup.Header>Trip Runtimes</Popup.Header>
              <Popup.Content>
                <List relaxed='very' divided>
                  <List.Item>
                    <List.Header>Regularly Scheduled</List.Header>
                    Time it would take a train to travel its current route, if trains ran on a typical schedule for the current time period.
                  </List.Item>
                  <List.Item>
                    <List.Header>Currently Scheduled</List.Header>
                    Time scheduled for a train to travel its route from the current supplemented schedule, taking into account of service changes and diversions.
                  </List.Item>
                  <List.Item>
                    <List.Header>Now</List.Header>
                    Estimated time for a train to travel its current route, projected from recent trains that have traveled the route.
                  </List.Item>
                </List>
              </Popup.Content>
            </Popup>
          </Header>
        </Divider>
        <Statistic.Group widths={3} size="small" inverted color={runtimeDiffAboutThreshold ? 'yellow' : 'black'}>
          <Statistic>
            <Statistic.Value>{ scheduledRuntime } <span className='minute'>min</span></Statistic.Value>
            <Statistic.Label>Reg. Sched.</Statistic.Label>
          </Statistic>
          <Statistic>
            <Statistic.Value>{ supplementedRuntime } <span className='minute'>min</span></Statistic.Value>
            <Statistic.Label>Curr. Sched.</Statistic.Label>
          </Statistic>
          <Statistic>
            <Statistic.Value>{ estimatedRuntime } <span className='minute'>min</span></Statistic.Value>
            <Statistic.Label>Now</Statistic.Label>
          </Statistic>
        </Statistic.Group>
      </React.Fragment>
    );
  }

  travelTimeFrom() {
    const { train, direction, stations } = this.props;
    const { travelTimeTo, selectedRouting } = this.state;

    if (selectedRouting === 'blended') {
      const routings = train.actual_routings[direction].filter((r) => r.includes(travelTimeTo)).map((r) => {
        const i = r.indexOf(travelTimeTo);
        return r.slice(0, i);
      });
      return [...new Set(routings.flat())].map((stopId) => {
        return {
          key: stopId,
          text: formatStation(stations[stopId].name),
          value: stopId,
        };
      });
    }
    const routing = train.actual_routings[direction].find((r) => selectedRouting === `${r[0]}-${r[r.length - 1]}-${r.length}`);

    if (!routing) {
      return;
    }

    const i = routing.indexOf(travelTimeTo);
    return routing.slice(0, i).map((stopId) => {
      return {
        key: stopId,
        text: formatStation(stations[stopId].name),
        value: stopId,
      };
    });
  }

  travelTimeTo() {
    const { train, direction, stations } = this.props;
    const { travelTimeFrom, selectedRouting } = this.state;

    if (selectedRouting === 'blended') {
      const routings = train.actual_routings[direction].filter((r) => r.includes(travelTimeFrom)).map((r) => {
        const i = r.indexOf(travelTimeFrom);
        return r.slice(i + 1);
      });
      return [...new Set(routings.flat())].map((stopId) => {
        return {
          key: stopId,
          text: formatStation(stations[stopId].name),
          value: stopId,
        };
      });
    }
    const routing = train.actual_routings[direction].find((r) => selectedRouting === `${r[0]}-${r[r.length - 1]}-${r.length}`);


    if (!routing) {
      return;
    }

    const i = routing.indexOf(travelTimeFrom);
    return routing.slice(i + 1).map((stopId) => {
      return {
        key: stopId,
        text: formatStation(stations[stopId].name),
        value: stopId,
      };
    });
  }

  renderTravelTime() {
    const { train, direction } = this.props;
    const { travelTimeFrom, travelTimeTo } = this.state;
    const scheduledRuntime = this.calculateRuntime(train.actual_routings && train.actual_routings[direction], train.scheduled_travel_times, travelTimeFrom, travelTimeTo);
    const supplementedRuntime = this.calculateRuntime(train.actual_routings && train.actual_routings[direction], train.supplemented_travel_times, travelTimeFrom, travelTimeTo);
    const estimatedRuntime = this.calculateRuntime(train.actual_routings && train.actual_routings[direction], train.estimated_travel_times, travelTimeFrom, travelTimeTo);
    const runtimeDiffAboveThreshold = estimatedRuntime - scheduledRuntime >= 5;
    return (
      <React.Fragment>
        <Divider inverted horizontal>
          <Header size='medium' inverted>
            TRAVEL TIME
            <Popup trigger={<sup>[?]</sup>}>
              <Popup.Header>Trip Runtimes</Popup.Header>
              <Popup.Content>
                <List relaxed='very' divided>
                  <List.Item>
                    <List.Header>Regularly Scheduled</List.Header>
                    Time it would take a train to travel between the 2 selected stations via its current route, if trains ran on a typical schedule for the current time period.
                  </List.Item>
                  <List.Item>
                    <List.Header>Currently Scheduled</List.Header>
                    Time scheduled for a train to travel between the 2 selected stations according to the current supplemented schedule, taking into account of service changes and diversions.
                  </List.Item>
                  <List.Item>
                    <List.Header>Now</List.Header>
                    Estimated time for a train to travel between the 2 selected stations via its current route, projected from recent trains that have traveled the route.
                  </List.Item>
                </List>
              </Popup.Content>
            </Popup>
          </Header>
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
        <Statistic.Group widths={3} size="small" inverted color={runtimeDiffAboveThreshold ? 'yellow' : 'black'}>
          <Statistic>
            <Statistic.Value>{ scheduledRuntime } <span className='minute'>min</span></Statistic.Value>
            <Statistic.Label>Reg. Sched</Statistic.Label>
          </Statistic>
          <Statistic>
            <Statistic.Value>{ supplementedRuntime } <span className='minute'>min</span></Statistic.Value>
            <Statistic.Label>Curr. Sched</Statistic.Label>
          </Statistic>
          <Statistic>
            <Statistic.Value>{ estimatedRuntime } <span className='minute'>min</span></Statistic.Value>
            <Statistic.Label>Now</Statistic.Label>
          </Statistic>
        </Statistic.Group>
      </React.Fragment>
    );
  }

  routingOptions() {
    const { train, stations } = this.props;
    const { routings, selectedRouting } = this.state;
    const options = Object.keys(routings).map((hash) => {
      const routing = routings[hash];
      return {
        key: hash,
        text: `${formatStation(stations[routing[0]].name)} ➜ ${formatStation(stations[routing[routing.length - 1]].name)} (${routing.length} stops)`,
        value: hash,
      };
    });
    options.unshift({
      key: 'blended',
      text: "All Routings",
      value: 'blended',
    });
    return options;
  }

  handleOptionChange = (e, { name, value }) => {
    const { train, direction } = this.props;
    const { selectedRouting } = this.state;
    const prevValue = this.state[name];

    if (prevValue === value) {
      return;
    }

    const newState = { [name]: value };
    if (name === 'selectedRouting' && value !== 'blended') {
      const routing = train.actual_routings[direction].find((r) => value === `${r[0]}-${r[r.length - 1]}-${r.length}`);
      newState['travelTimeFrom'] = routing[0];
      newState['travelTimeTo'] = routing[routing.length - 1];
    }
    this.setState(newState);
  };

  handleToggleChange = (e, {checked}) => {
    this.setState({displayAdditionalTrips: checked});
  }

  renderTripsTableBody(selectedRouting, trips, segment = []) {
    const { train, trains, direction, match, stations } = this.props;
    const directionKey = direction[0].toUpperCase();
    const currentTime = Date.now() / 1000;
    let scheduledHeadways = train.scheduled_headways[direction] && train.scheduled_headways[direction][selectedRouting];
    if (!scheduledHeadways && train.scheduled_headways[direction]) {
      const key = Object.keys(train.scheduled_headways[direction])[0];
      scheduledHeadways = train.scheduled_headways[direction][key];
    }
    const maxScheduledHeadway = scheduledHeadways ? Math.round(Math.max(...scheduledHeadways) / 60) : Infinity;

    return (
      <React.Fragment>
        {
          trips.map((trip) => {
            const delayed = trip.delayed_time > 300;
            const effectiveDelayedTime = Math.max(Math.min(trip.schedule_discrepancy, trip.delayed_time), 0);
            const delayedTime = trip.is_delayed ? effectiveDelayedTime : trip.delayed_time;
            const delayInfo = delayed ? `(${trip.is_delayed ? 'delayed' : 'held'} for ${Math.round(delayedTime / 60)} mins)` : '';
            const estimatedTimeUntilUpcomingStop = Math.round((trip.estimated_upcoming_stop_arrival_time - currentTime) / 60);
            let estimatedTimeBehindNextTrainSeconds = trip.estimated_time_behind_next_train;
            if (!estimatedTimeBehindNextTrainSeconds) {
              estimatedTimeBehindNextTrainSeconds = trip.estimated_time_until_destination;
            }
            const estimatedTimeBehindNextTrain = estimatedTimeBehindNextTrainSeconds && Math.round(Math.max(estimatedTimeBehindNextTrainSeconds, 0) / 60);
            const scheduleDiscrepancy = trip.schedule_discrepancy !== null ? Math.round(trip.schedule_discrepancy / 60) : 0;
            const tripIsPartOfRoute = trip.route_id === train.id;
            let scheduleDiscrepancyClass = 'early';
            if (Math.round(trip.schedule_discrepancy / 60) >= 1) {
              scheduleDiscrepancyClass = 'late';
            }
            let className = '';
            if (delayed) {
              className += 'delayed ';
            }
            if (!trip.is_assigned) {
              className += 'unassigned ';
            }
            const selectedTrain = !tripIsPartOfRoute && trains[trip.route_id];
            return (
              <Table.Row key={trip.id} className={className}>
                <Table.Cell>
                  <Link to={`/trains/${trip.route_id || train.id}/${trip.direction ? trip.direction[0].toUpperCase() : directionKey}/${trip.id}`} className='trip-id-link'>
                    <div className="trip-id">
                      { selectedTrain &&
                        <TrainBullet name={selectedTrain.name} color={selectedTrain.color} textColor={selectedTrain.text_color} style={{display: "inline-block"}} key={selectedTrain.id} size='small' />
                      }
                      { trip.id.replace(/_/g, '\u200B_') }&nbsp;
                    </div>
                    <div className="trip-destination">
                      to { formatStation(stations[trip.destination_stop].name.replace(/\//g, '/\u200B').replace(/–/g, '–\u200B'))}
                    </div>
                  </Link>
                  {delayInfo && <Header as='h5' className='delayed-text' inverted color='red'>{delayInfo}</Header> }
                </Table.Cell>
                <Table.Cell title={new Date(trip.estimated_upcoming_stop_arrival_time * 1000).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit'})}>
                  { trip.is_assigned || delayed ? '' : '~' }{ formatMinutes(estimatedTimeUntilUpcomingStop, trip.is_assigned) } { estimatedTimeUntilUpcomingStop > 0 || !trip.is_assigned ? 'until' : 'at'}&nbsp;
                  <Link to={`/stations/${trip.upcoming_stop}`} className='station-name'>
                    { formatStation(stations[trip.upcoming_stop].name.replace(/\//g, '/\u200B').replace(/–/g, '–\u200B')) }
                  </Link>
                </Table.Cell>
                <Table.Cell className={tripIsPartOfRoute && estimatedTimeBehindNextTrain > maxScheduledHeadway ? 'long-headway' : ''}>
                  { tripIsPartOfRoute &&
                    <>
                      { trip.is_assigned || delayed ? '' : '~' }{ delayed ? '? ? ?' : (estimatedTimeBehindNextTrain !== null && (trip.estimated_time_behind_next_train !== null ? formatMinutes(estimatedTimeBehindNextTrain, false) : `${formatMinutes(estimatedTimeBehindNextTrain, false)} to end`)) }
                    </>
                  }
                  { !tripIsPartOfRoute &&
                    <>
                      --
                    </>
                  }
                </Table.Cell>
                <Table.Cell className={scheduleDiscrepancyClass}>
                  { scheduleDiscrepancy !== null && formatMinutes(scheduleDiscrepancy, false, true) }
                </Table.Cell>
              </Table.Row>
            )
          })
        }
      </React.Fragment>
    );
  }

  renderBlendedTripsTable(train, direction) {
    const { displayAdditionalTrips } = this.state;

    const tripsObj = displayAdditionalTrips ? train.trips_including_other_routes_on_shared_tracks[direction] : train.trips[direction];
    const commonRouting = train.common_routings[direction];
    const commonRoutingTrips = tripsObj.blended || [];
    let remainingTrips = Object.keys(tripsObj).filter((key) => key !== 'blended').flatMap((key) => tripsObj[key]).filter((trip) => !commonRoutingTrips.map((trip) => trip.id).includes(trip.id));
    remainingTrips = remainingTrips.filter((value, index, array) => array.indexOf(array.find((t) => t.id === value.id)) === index);
    const componentArray = [];

    Object.keys(tripsObj).filter((key) => key !== 'blended').sort((a, b) => {
      const aTrips = tripsObj[a];
      const bTrips = tripsObj[b];
      return bTrips.length - aTrips.length;
    }).forEach((key) => {
      const a = key.split('-');
      if (!commonRouting) {
        const start  = a[0];
        const end = a[1];
        const selectedTrips = tripsObj[key];
        componentArray.push(this.renderSingleRoutingTable(train, key, direction, selectedTrips));
        return;
      }
      if (commonRouting.includes(a[0])) {
        return;
      }
      const routing = train.actual_routings[direction].find((r) => key === `${r[0]}-${r[r.length - 1]}-${r.length}`);
      const i = routing.indexOf(commonRouting[0]);
      const subrouting = routing.slice(0, i);
      const trips = subrouting.map((stopId) => remainingTrips.filter((trip) => trip.upcoming_stop === stopId)).map((trips) => trips.sort((a, b) => b.estimated_upcoming_stop_arrival_time - a.estimated_upcoming_stop_arrival_time)).flat();
      remainingTrips = remainingTrips.filter((trip => !trips.map((t) => t.id).includes(trip.id)));
      if (trips.length > 0) {
        componentArray.push(this.renderSingleRoutingTable(train, key, direction, trips, subrouting[0], commonRouting[0]));
      }
    });

    if (commonRoutingTrips.length > 0) {
      componentArray.push(this.renderSingleRoutingTable(train, 'blended', direction, commonRoutingTrips, commonRouting[0], commonRouting[commonRouting.length - 1]));
    }

    const routesAfter = Object.keys(tripsObj).filter((key) => key !== 'blended').sort((a, b) => {
      const aTrips = tripsObj[a];
      const bTrips = tripsObj[b];
      return bTrips.length - aTrips.length;
    }).forEach((key) => {
      const a = key.split('-');
      if (!commonRouting) {
        return;
      }
      if (commonRouting.includes(a[1])) {
        return;
      }
      const routing = train.actual_routings[direction].find((r) => key === `${r[0]}-${r[r.length - 1]}-${r.length}`);
      const i = routing.indexOf(commonRouting[commonRouting.length - 1]);
      const subrouting = routing.slice(i + 1);
      const trips = remainingTrips.filter((trip) => subrouting.includes(trip.upcoming_stop));
      remainingTrips = remainingTrips.filter((trip => !trips.map((t) => t.id).includes(trip.id)));
      if (trips.length > 0) {
        componentArray.push(this.renderSingleRoutingTable(train, key, direction, trips, commonRouting[commonRouting.length - 1], subrouting[subrouting.length - 1]));
      }
    });

    return (
      <Table fixed inverted unstackable size='small' compact className='trip-table' columns={4}>
        <Table.Header>
          <Table.Row>
            <Table.HeaderCell width={6}>
              Trip ID / Destination
            </Table.HeaderCell>
            <Table.HeaderCell width={5}>
              Current Location
            </Table.HeaderCell>
            <Table.HeaderCell>
              <span>Time Behind Next Train</span>
            </Table.HeaderCell>
            <Table.HeaderCell>
              Schedule Adherence
            </Table.HeaderCell>
          </Table.Row>
        </Table.Header>
        <Table.Body>
          {
            componentArray
          }
        </Table.Body>
      </Table>
    );
  }

  renderTableSection(selectedRouting, trips, start, end, routes = [], segment = []) {
    const { train, trains, direction, stations } = this.props;
    const { displayAdditionalTrips } = this.state;
    const startName = formatStation(stations[start].name);
    const endName = formatStation(stations[end].name);
    const renderRoutes = routes.sort().map((str) => {
      const tuple = str.split('|');
      const route = tuple[0];
      const direction = tuple[1];
      const selectedTrain = trains[route];
      return (<TrainBullet name={selectedTrain.name} link={true} linkedView={direction[0].toUpperCase()} id={selectedTrain.id} color={selectedTrain.color}
        textColor={selectedTrain.text_color} style={{display: "inline-block"}} key={selectedTrain.id} size='small' />);
    });
    const hasSharedTracks = train.routes_with_shared_tracks && train.routes_with_shared_tracks[direction] && Object.keys(train.routes_with_shared_tracks[direction]).length > 0;
    const displayHeader = displayAdditionalTrips && hasSharedTracks;

    return (
      <React.Fragment key={`${start}-${end}`}>
        { displayHeader &&
          <Table.Row key={`${start}-${end} heading`}>
            <Table.Cell colSpan={4}>
                <Header as='h5' inverted textAlign='left'>
                  <>
                    <span>{startName} ➜ {endName}</span>
                    { routes.length > 0 &&
                      <span className="concurrent-trains"> (with
                        {
                          renderRoutes
                        }
                      )</span>
                    }
                  </>
                </Header>
            </Table.Cell>
          </Table.Row>
        }
        { this.renderTripsTableBody(selectedRouting, trips, segment) }
      </React.Fragment>
    );
  }

  renderSingleTable(train, direction) {
    const { selectedRouting, displayAdditionalTrips } = this.state;

    const tripsObj = displayAdditionalTrips ? train.trips_including_other_routes_on_shared_tracks[direction] : train.trips[direction];
    let trips = tripsObj[selectedRouting];
    let routing = selectedRouting;

    if (!trips) {
      const key = Object.keys(tripsObj)[0];
      trips = tripsObj[key];

      if (selectedRouting === 'blended') {
        routing = key;
      }
    }

    return (<Table fixed inverted unstackable size='small' compact className='trip-table' columns={4}>
        <Table.Header>
          <Table.Row>
            <Table.HeaderCell width={6}>
              Trip ID / Destination
            </Table.HeaderCell>
            <Table.HeaderCell width={5}>
              Current Location
            </Table.HeaderCell>
            <Table.HeaderCell>
              <span>Time Behind Next Train</span>
            </Table.HeaderCell>
            <Table.HeaderCell>
              Schedule Adherence
            </Table.HeaderCell>
          </Table.Row>
        </Table.Header>
        <Table.Body>
          {
            this.renderSingleRoutingTable(train, routing, direction, trips)
          }
        </Table.Body>
      </Table>
    );
  }

  renderSingleRoutingTable(train, selectedRouting, direction, trips, start, end) {
    let routing = selectedRouting === 'blended' ? train.common_routings[direction] : train.actual_routings[direction].find((r) => selectedRouting === `${r[0]}-${r[r.length - 1]}-${r.length}`);
    if (start && end) {
      const a = routing.indexOf(start);
      const b = routing.indexOf(end);
      routing = routing.slice(a, b + 1)
    }
    const stopsSharedWithOtherRoutes = train.routes_with_shared_tracks[direction];
    const componentArray = [];
    let currentSharedRoutes = stopsSharedWithOtherRoutes[routing[0]] || {};
    let currentSegment = [];

    routing.forEach((stopId) => {
      const thisStopSharedRoutesArray = Object.keys(stopsSharedWithOtherRoutes[stopId] || {}).flatMap((r) => stopsSharedWithOtherRoutes[stopId][r].map((dir) => `${r}|${dir}`));
      const currentSharedRoutesArray = Object.keys(currentSharedRoutes).flatMap((key) => currentSharedRoutes[key].map((dir) => `${key}|${dir}`));
      if (thisStopSharedRoutesArray.length === currentSharedRoutesArray.length &&
            thisStopSharedRoutesArray.every((r) => currentSharedRoutesArray.includes(r))) {
        currentSegment.push(stopId);
      } else {
        const selectedTrips = trips.filter((t) => currentSegment.includes(t.upcoming_stop));
        componentArray.push(
          this.renderTableSection(
            selectedRouting,
            selectedTrips,
            currentSegment[0],
            currentSegment[currentSegment.length - 1],
            currentSharedRoutesArray,
            currentSegment,
          )
        );
        currentSegment = [stopId];
        currentSharedRoutes = stopsSharedWithOtherRoutes[stopId] || {};
      }
    });

    const selectedTrips = trips.filter((t) => currentSegment.includes(t.upcoming_stop));
    const currentSharedRoutesArray = Object.keys(currentSharedRoutes).flatMap((key) => currentSharedRoutes[key].map((dir) => `${key}|${dir}`));

    componentArray.push(
      this.renderTableSection(
        selectedRouting,
        selectedTrips,
        currentSegment[0],
        currentSegment[currentSegment.length - 1],
        currentSharedRoutesArray,
        currentSegment,
      )
    );

    return componentArray;
  }

  render() {
    const { trains, train, direction, stations } = this.props;
    const { selectedRouting, routings, travelTimeFrom, travelTimeTo, displayAdditionalTrips } = this.state;
    const routingToMap = selectedRouting === 'blended' ? train.actual_routings && train.actual_routings[direction] : [routings[selectedRouting]];
    let tripsForMap = [];
    if (train.trips && train.trips[direction]) {
      const tripsObj = displayAdditionalTrips ? train.trips_including_other_routes_on_shared_tracks[direction] : train.trips[direction];
      tripsForMap = tripsObj[selectedRouting] || [];

      if (selectedRouting === 'blended') {
        tripsForMap = Object.keys(tripsObj).filter((key) => key !== 'blended').flatMap((key) => tripsObj[key])
        tripsForMap = tripsForMap.filter((value, index, array) => array.indexOf(array.find((t) => t.id === value.id)) === index);
      }
    }
    const hasSharedTracks = train.routes_with_shared_tracks && train.routes_with_shared_tracks[direction] && Object.keys(train.routes_with_shared_tracks[direction]).length > 0;
    return (
      <Segment basic className='train-modal-direction-pane'>
        <Grid textAlign='center' stackable>
          <Grid.Row>
            <Grid.Column className='map-cell' computer={4} tablet={6} mobile={6}>
            {
              train.actual_routings && train.actual_routings[direction] &&
                <TrainMap trains={trains} train={train} stations={stations} routings={{ south: routingToMap, north: [] }} scheduledRoutings={train.scheduled_routings} showTravelTime direction={direction} trips={tripsForMap} />
            }
            </Grid.Column>
            <Grid.Column className='trip-table-cell' computer={12} tablet={10} mobile={10}>
              <Statistic.Group widths={1} color={ statusColor(this.directionStatus()) } size='small' inverted>
                <Statistic>
                  <Statistic.Value>{ this.directionStatus() }</Statistic.Value>
                  <Statistic.Label>
                    {train.destinations && train.destinations[direction] ? `${formatStation(train.destinations[direction].join('/'))}-bound trains Status` : 'Status' }
                    { twitterLink(train.id) }
                  </Statistic.Label>
                </Statistic>
              </Statistic.Group>
              {
                this.renderDelays()
              }
              {
                this.renderServiceChanges()
              }
              {
                this.renderServiceIrregularities()
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
              {
                train.trips && train.trips[direction] &&
                <Divider inverted horizontal>
                  <Header size='medium' inverted>
                    ACTIVE TRIPS
                    <Popup trigger={<sup>[?]</sup>}>
                      <Popup.Header>Active Trips</Popup.Header>
                      <Popup.Content>
                        <List relaxed='very' divided>
                          <List.Item>
                            <List.Header>Current Location</List.Header>
                            Projected time until train arrives at its next stop, calculated from train's estimated position and recent trips.
                          </List.Item>
                          <List.Item>
                            <List.Header>Time Behind Next Train</List.Header>
                            Projected time behind next train ahead, calculated from trains' estimated positions and travel times of recent trips.
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
              }
              {
                hasSharedTracks &&
                  <Checkbox checked={displayAdditionalTrips} onChange={this.handleToggleChange} className='additional-trips-toggle' toggle label={<label className="toggle-label">Show other trains that share tracks</label>} />
              }
              {
                train.trips && train.trips[direction] && selectedRouting === 'blended' && Object.keys(routings).length > 1 &&
                this.renderBlendedTripsTable(train, direction)
              }
              { train.trips && train.trips[direction] && (Object.keys(routings).length === 1 || selectedRouting !== 'blended') &&
                this.renderSingleTable(train, direction)
              }
            </Grid.Column>
            <Grid.Column width={4} className='mobile-map-cell'>
            {
              train.actual_routings && train.actual_routings[direction] &&
                <TrainMap trains={trains} train={train} stations={stations} routings={{ south: routingToMap, north: [] }} scheduledRoutings={train.scheduled_routings} showTravelTime direction={direction} trips={tripsForMap} />
            }
            </Grid.Column>
         </Grid.Row>
        </Grid>
      </Segment>
    )
  }
}

export default TrainModalDirectionPane;