import React from 'react';
import { Header, Segment, Grid, Button, Dimmer, Loader } from "semantic-ui-react";
import Train from './train';
import 'semantic-ui-css/semantic.min.css'

const API_URL = '/api/routes';

class App extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      trains: [],
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

  render() {
    const { trains, timestamp } = this.state;
    const trainKeys = Object.keys(trains);
    return (
      <div>
        <Segment inverted vertical className='header-segment'>
          <Header inverted as='h1' color='blue'>
            goodservice.io
            <Header.Subheader>
              New York City Subway Status Page
            </Header.Subheader>
          </Header>
        </Segment>
        <Segment inverted vertical className='blogpost-segment'>
          Blog post goes here
        </Segment>
        <Segment basic className='trains-segment'>
          <Grid stackable columns={3}>
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
                    <Train train={train} />
                  </Grid.Column>)
              })
            }
          </Grid>
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
      </div>
    );
  }
}

export default App;
