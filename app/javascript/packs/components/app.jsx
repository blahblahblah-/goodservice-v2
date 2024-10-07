import React from 'react';
import { Header, Segment, Grid, Dimmer, Loader, Dropdown, List, Tab, Menu, Message } from "semantic-ui-react";
import {
  Router,
  Switch,
  Route,
  Redirect,
  Link,
} from 'react-router-dom';
import { Helmet } from "react-helmet";
import * as Cookies from 'es-cookie';

import TrainGrid from './trainGrid';
import StationList from './stationList';
import AboutModal from './aboutModal';
import StationModal from './stationModal';
import TwitterModal from './twitterModal';

import Footer from './footer';
import history from './history';

import 'semantic-ui-css/semantic.min.css'

const ROUTES_API_URL = '/api/routes';
const STOPS_API_URL = '/api/stops';

class App extends React.Component {
  constructor(props) {
    super(props);
    const favStationsStr = Cookies.get('favStations');
    const favStations = favStationsStr?.split(",");
    this.state = {
      trains: {},
      loading: false,
      favStations: new Set(favStations),
    };
    if (favStationsStr) {
      Cookies.set('favStations', favStationsStr, {expires: 365});
    }
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

  handlePinStation = (stationId) => {
    const { favStations } = this.state;
    favStations.add(stationId);
    this.setState({favStations: favStations});
    Cookies.set('favStations', [...favStations].join(','), {expires: 365});
  }

  handleUnpinStation = (stationId) => {
    const { favStations } = this.state;
    favStations.delete(stationId);
    this.setState({favStations: favStations});
    Cookies.set('favStations', [...favStations].join(','), {expires: 365});
  }

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

  renderAbout() {
    return (
      <React.Fragment>
        <AboutModal open={true} />
        <Tab panes={this.renderPanes()} activeIndex="0" />
      </React.Fragment>
    );
  }

  renderTwitter() {
    return (
      <React.Fragment>
        <TwitterModal open={true} />
        <Tab panes={this.renderPanes()} activeIndex="0" />
      </React.Fragment>
    );
  }

  renderStations() {
    const { trains, stations, favStations } = this.state;

    return (
      <StationList trains={trains} stations={stations} favStations={favStations} selectedStationId={this.selectedStationId} />
    );
  }

  renderStation(stationId) {
    const { trains, stations, favStations } = this.state;
    const selectedStation = stations.find((s) => s.id === stationId);
    const stationsObj = {};
    stations.forEach((s) => {
      stationsObj[s.id] = s;
    })
    return (
      <React.Fragment>
        <StationModal open={true} stations={stationsObj} isFavStation={favStations.has(stationId)}
          handlePinStation={this.handlePinStation} handleUnpinStation={this.handleUnpinStation}
          trains={trains} selectedStation={selectedStation}
        />
        {
          this.renderStations()
        }
      </React.Fragment>
    );
  }

  renderTrains(selectedTrain) {
    const { trains, stations } = this.state;
    return (
      <TrainGrid selectedTrain={selectedTrain} trains={trains} stations={stations} />
    )
  }

  renderPanes() {
    const { trains, stations } = this.state;
    const trainKeys = Object.keys(trains);
    return [
      { menuItem: <Menu.Item as={Link} to='/trains' key='trains'>Trains</Menu.Item>,
        render: () =>
          <Tab.Pane inverted>
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
                  <Route path='/trains' render={() => {
                    return this.renderTrains(null);
                  }} />
                  <Route path='/about' render={() => {
                    return this.renderTrains(null);
                  }} />
                  <Route path='/twitter' render={() => {
                    return this.renderTrains(null);
                  }} />
                  <Route render={() => <Redirect to="/trains" /> } />
                </Switch>
              }
          </Tab.Pane>
      },
      { menuItem: <Menu.Item as={Link} to='/stations' key='stations'>Stations</Menu.Item>,
        render: () =>
          <Tab.Pane inverted>
            { this.renderLoading() }
              { trainKeys.length > 0 && stations &&
                <Switch>
                  <Route path='/stations/:id' render={(props) => {
                    this.selectedStationId = props.match.params.id;
                    const stationIds = stations.map((s) => s.id);
                    if (props.match.params.id && stationIds.includes(props.match.params.id)) {
                      return this.renderStation(props.match.params.id);
                    } else {
                      return (<Redirect to="/" />);
                    }
                  }} />
                  <Route path='/stations' render={() => {
                    this.selectedStationId = null;
                    return this.renderStations();
                  }} />
                  <Route render={() => <Redirect to="/stations" /> } />
                </Switch>
              }
          </Tab.Pane>
      },
    ];
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
            <link rel="canonical" href="https://www.goodservice.io" />
            <meta property="og:url" content="https://www.goodservice.io" />
            <meta name="twitter:url" content="https://www.goodservice.io" />
          </Helmet>
        </Segment>
        <Segment inverted vertical className='blogpost-segment'>
        </Segment>
        <Segment basic className='content-segment'>
          <Switch>
            <Route path="/trains" render={() => <Tab menu={{pointing: true, secondary: true, inverted: true}} panes={this.renderPanes()} activeIndex="0" />} />
            <Route path="/stations" render={() => <Tab menu={{pointing: true, secondary: true, inverted: true}} panes={this.renderPanes()} activeIndex="1" />} />
            <Route path='/about' render={() => {
              return this.renderAbout();
            }} />
            <Route path='/twitter' render={() => {
              return this.renderTwitter();
            }} />
            <Route render={() => <Redirect to="/trains" />} />
          </Switch>
        </Segment>
        <Footer timestamp={timestamp} />
      </Router>
    );
  }
}

export default App;
