import React from 'react';
import { Header, Segment, Grid, Button, Dimmer, Loader, Dropdown } from "semantic-ui-react";
import {
  Router,
  Switch,
  Route,
  Redirect,
  Link,
} from 'react-router-dom';
import { groupBy } from 'lodash';
import { Helmet } from "react-helmet";

import Train from './train';
import TrainBullet from './trainBullet';
import AboutModal from './aboutModal';
import StationModal from './stationModal';
import history from './history';
import { formatStation } from './utils';
import { accessibilityIcon } from './accessibility.jsx';
import Cross from 'images/cross-15.svg'

import 'semantic-ui-css/semantic.min.css'

const ROUTES_API_URL = '/api/routes';
const STOPS_API_URL = '/api/stops';

const STATUSES = {
  'Delay': 'red',
  'No Service': 'black',
  'Service Change': 'orange',
  'Slow': 'yellow',
  'Not Good': 'yellow',
  'Good Service': 'green',
  'Not Scheduled': 'black'
};

class App extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      trains: {},
      loading: false,
    };
  }

  componentWillUnmount() {
    clearInterval(this.timer);
  }

  componentDidMount() {
    this.setState({loading: true});
    this.fetchData();
    this.timer = setInterval(() => this.fetchData(), 15000);
  }

  fetchData() {
    fetch(ROUTES_API_URL)
      .then(response => response.json())
      .then(data => this.setState({ trains: data.routes, timestamp: data.timestamp, loading: false }));

    fetch(STOPS_API_URL)
      .then(response => response.json())
      .then(data => this.setState({ stations: data.stops }));
  }

  handleOnStationDropdownChange = (e, { name, value }) => {
    return history.push(`/stations/${value}`);
  };

  renderLoading() {
    const { loading } = this.state;
    if (loading) {
      return(
        <Dimmer active>
          <Loader inverted></Loader>
        </Dimmer>
      )
    }
  }

  renderStationsDropdown() {
    const { loading, trains, stations } = this.state;
    if (loading || !stations) {
      return;
    }
    const options = stations.map((station) => {
      return {
        key: station.id,
        text: formatStation(station.name),
        value: station.id,
        content: (
          <React.Fragment>
            <div className='station-name'>
              <Header as='h5'>
                { formatStation(station.name) }
                {
                  station.secondary_name &&
                  <span className='secondary-name'>
                    { station.secondary_name }
                  </span>
                }
                {
                  accessibilityIcon(station.accessibility)
                }
              </Header>
            </div>
            <div className='routes-served'>
              {
                Object.keys(station.routes).map((routeId) => {
                  const directions = station.routes[routeId];
                  const train = trains[routeId];
                  return (
                    <TrainBullet id={routeId} key={train.name} name={train.name} color={train.color}
                      textColor={train.text_color} size='small' key={train.id} directions={directions} />
                  );
                })
              }
              {
                Object.keys(station.routes).length === 0 &&
                <img src={Cross} className='cross' />
              }
            </div>
         </React.Fragment>
        )
      }
    });

    return (
      <Grid columns={3} className='station-dropdown-grid' stackable>
        <Grid.Row>
          <Grid.Column>
            <Dropdown
            button
            search
            fluid
            selectOnNavigation={false}
            options={options}
            onChange={this.handleOnStationDropdownChange}
            text='Select Station...'
            value={null}
            />
          </Grid.Column>
        </Grid.Row>
      </Grid>
    );
  }

  renderAbout() {
    return (
      <React.Fragment>
        <AboutModal open={true} />
        {
          this.renderTrains(null)
        }
      </React.Fragment>
    );
  }

  renderStation(stationId) {
    const { trains, stations } = this.state;
    const selectedStation = stations.find((s) => s.id === stationId);
    const stationsObj = {};
    stations.forEach((s) => {
      stationsObj[s.id] = s;
    })
    return (
      <React.Fragment>
        <StationModal open={true} stations={stationsObj} trains={trains} selectedStation={selectedStation} />
        {
          this.renderTrains(null)
        }
      </React.Fragment>
    );
  }

  renderTrains(selectedTrain) {
    const { trains, timestamp, stations } = this.state;
    const trainKeys = Object.keys(trains);
    let groups = groupBy(trains, 'status');
    const stationsObj = {};
    stations.forEach((s) => {
      stationsObj[s.id] = s;
    })
    return (
      <React.Fragment>
        <Grid columns={6} doubling className='train-grid'>
        {
          stations && trainKeys.map(trainId => trains[trainId]).sort((a, b) => {
            const nameA = `${a.name} ${a.alternate_name}`;
            const nameB = `${b.name} ${b.alternate_name}`;
            if (nameA < nameB) {
              return -1;
            }
            if (nameA > nameB) {
              return 1;
            }
            return 0;
          }).map(train => {
            const visible = train.visible || train.status !== 'Not Scheduled';
            return (
              <Grid.Column key={train.id} style={{display: (visible ? 'block' : 'none')}}>
                <Train train={train} trains={trains} stations={stationsObj} selected={selectedTrain === train.id} />
              </Grid.Column>)
          })
        }
        </Grid>
        <Grid className='mobile-train-grid'>
          {
            Object.keys(STATUSES).filter((s) => groups[s]).map((status) => {
              return (
                <React.Fragment key={status}>
                  <Grid.Row columns={1} className='train-status-row'>
                    <Grid.Column><Header size='small' color={STATUSES[status]} inverted>{status}</Header></Grid.Column>
                  </Grid.Row>
                  <Grid.Row columns={6} textAlign='center'>
                    {
                      groups[status].map(train => {
                        const visible = train.visible || train.status !== 'Not Scheduled';
                        return (
                          <Grid.Column key={train.name + train.alternate_name} style={{display: (visible ? 'block' : 'none')}}>
                            <Link to={`/trains/${train.id}`}>
                              <TrainBullet name={train.name} alternateName={train.alternate_name && train.alternate_name[0]} color={train.color} size='small'
                                              textColor={train.text_color} style={{ float: 'left' }} />
                            </Link>
                          </Grid.Column>
                        )
                      })
                    }
                  </Grid.Row>
                </React.Fragment>
              )
            })
          }
        </Grid>
      </React.Fragment>
    );
  }

  render() {
    const { trains, timestamp, loading, stations } = this.state;
    const trainKeys = Object.keys(trains);
    return (
      <Router history={history}>
        <Segment inverted vertical className='header-segment'>
          <Header inverted as='h1' color='yellow'>
            goodservice.io
            <Header.Subheader>
              New York City Subway Status Page
                <sup>[<Link to='/about'>?</Link>]</sup>
            </Header.Subheader>
          </Header>
          <Helmet>
            <title>goodservice.io - New York City Subway Status Page</title>
            <meta property="og:title" content="goodservice.io" />
            <meta name="twitter:title" content="goodservice.io" />
          </Helmet>
        </Segment>
        <Segment inverted vertical className='blogpost-segment'>

        </Segment>
        <Segment inverted vertical className='stations-segment'>
          {
            this.renderStationsDropdown()
          }
        </Segment>
        <Segment basic className='trains-segment'>
            { this.renderLoading() }
            { trainKeys.length > 0 && stations &&
              <Switch>
                <Route path='/trains/:id/:direction?/:tripId?' render={(props) => {
                  if (props.match.params.id && trainKeys.includes(props.match.params.id)) {
                    return this.renderTrains(props.match.params.id);
                  } else {
                    return (<Redirect to="/" />);
                  }
                }} />
                <Route path='/stations/:id' render={(props) => {
                  const stationIds = stations.map((s) => s.id);
                  if (props.match.params.id && stationIds.includes(props.match.params.id)) {
                    return this.renderStation(props.match.params.id);
                  } else {
                    return (<Redirect to="/" />);
                  }
                }} />
                <Route path='/about' render={() => {
                  return this.renderAbout();
                }} />
                <Route path='/' render={() => {
                  return this.renderTrains(null);
                }} />
                <Route render={() => <Redirect to="/" /> } />
              </Switch>
            }
        </Segment>
        <Segment inverted vertical style={{padding: '1em 2em'}}>
          <Grid>
            <Grid.Column width={7}>
              <a href='https://www.medium.com/good-service' target='_blank'>
                <Button circular className='medium-icon' icon='medium m' />
              </a>
              <a href='https://twitter.com/goodservice_io' target='_blank'>
                <Button circular color='twitter' icon='twitter' />
              </a>
              <a href='https://www.goodservice.io/slack' target='_blank'>
                <Button circular className='slack-icon' icon={{ className: 'slack-icon' }} />
              </a>
            </Grid.Column>
            <Grid.Column width={9} textAlign='right'>
              <Header inverted as='h5'>
                Last updated {timestamp && (new Date(timestamp * 1000)).toLocaleTimeString('en-US')}.<br />
                Created by <a href='https://sunny.ng'>Sunny Ng</a>.<br />
                <a href='https://github.com/blahblahblah-/goodservice-v2'>Source code</a>.
              </Header>
            </Grid.Column>
          </Grid>
        </Segment>
      </Router>
    );
  }
}

export default App;
