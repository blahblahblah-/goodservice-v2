import React from 'react';
import { Header, Segment, Grid, Button, Dimmer, Loader } from "semantic-ui-react";
import {
  BrowserRouter as Router,
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

import 'semantic-ui-css/semantic.min.css'

const API_URL = '/api/routes';

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
    this.timer = setInterval(() => this.fetchData(), 30000);
  }

  fetchData() {
    fetch(API_URL)
      .then(response => response.json())
      .then(data => this.setState({ trains: data.routes, timestamp: data.timestamp, loading: false }))
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
      <>
        <AboutModal open={true} />
        {
          this.renderTrains(null)
        }
      </>
    );
  }

  renderTrains(selectedTrain) {
    const { trains, timestamp } = this.state;
    const trainKeys = Object.keys(trains);
    let groups = groupBy(trains, 'status');
    return (
      <>
        <Grid columns={3} className='train-grid'>
        {
          trainKeys.map(trainId => trains[trainId]).sort((a, b) => {
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
                <Train train={train} trains={trains} selected={selectedTrain === train.id} />
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
      </>
    );
  }

  render() {
    const { trains, timestamp, loading } = this.state;
    const trainKeys = Object.keys(trains);
    return (
      <Router>
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
        <Segment basic className='trains-segment'>
            { this.renderLoading() }
            { trainKeys.length > 0 &&
              <Switch>
                <Route path='/trains/:id/:tripId?' render={(props) => {
                  if (props.match.params.id && trainKeys.includes(props.match.params.id)) {
                    return this.renderTrains(props.match.params.id);
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
              <Button circular className='medium-icon' icon='medium m' onClick={() => window.open("https://www.medium.com/good-service")} />
              <Button circular color='twitter' icon='twitter' onClick={() => window.open("https://twitter.com/goodservice_io")} />
              <Button circular className='slack-icon' icon={{ className: 'slack-icon' }}  onClick={() => window.open("/slack")} />
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
