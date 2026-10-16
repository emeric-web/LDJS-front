import { render, screen } from '@testing-library/react';
import { createMemoryRouter, RouterProvider } from 'react-router';
import Home from '../../src/pages/Home';

function renderWithLoader(loaderData: unknown) {
  const router = createMemoryRouter(
    [
      {
        path: '/',
        element: <Home />,
      },
    ],
    {
      initialEntries: ['/'],
      hydrationData: {
        loaderData: { '0': loaderData },
      },
    }
  );

  return render(<RouterProvider router={router} />);
}

describe('Home Component', () => {
  it('should display olympics data', async () => {
    const mockData = [
      {
        id: 1,
        country: 'France',
        participations: [
          {
            id: 1,
            year: 2012,
            city: 'Londres',
            medalsCount: 34,
            athleteCount: 330,
          },
        ],
      },
    ];

    renderWithLoader(mockData);

    expect(await screen.findByText(/Jeux Olympiques/i)).toBeInTheDocument();
    expect(screen.getByText(/Donnees de 1 pays chargees/i)).toBeInTheDocument();
    expect(screen.getByText(/France/i)).toBeInTheDocument();
    expect(screen.getByText(/JO de Londres - 2012/i)).toBeInTheDocument();
  });

  it('should display multiple countries', async () => {
    const mockData = [
      { id: 1, country: 'France', participations: [] },
      { id: 2, country: 'Germany', participations: [] },
    ];

    renderWithLoader(mockData);

    expect(await screen.findByText(/Donnees de 2 pays chargees/i)).toBeInTheDocument();
    expect(screen.getByText(/France/i)).toBeInTheDocument();
    expect(screen.getByText(/Germany/i)).toBeInTheDocument();
  });
});
